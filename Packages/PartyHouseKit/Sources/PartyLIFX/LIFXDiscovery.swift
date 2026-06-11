import Foundation
import Network
import PartyCore

struct LIFXDevice: Hashable, Sendable {
    let serial: [UInt8]
    let host: String

    var serialString: String {
        serial.map { String(format: "%02x", $0) }.joined()
    }
}

/// Finds LIFX bulbs by sending unicast GetService probes across the local /24
/// subnet(s) plus any manually configured hosts. Unicast (rather than the
/// protocol's usual UDP broadcast) avoids needing the iOS multicast entitlement.
enum LIFXDiscovery {
    static func discover(manualHosts: [String], source: UInt32) async -> [LIFXDevice] {
        var candidates = Set(manualHosts.filter { !$0.isEmpty })
        candidates.formUnion(localSubnetHosts())

        var devices: Set<LIFXDevice> = []
        let probe = LIFXPacket.getService(source: source, sequence: 0)

        // Probe in batches to keep socket counts sane.
        let hosts = Array(candidates)
        let batchSize = 32
        for batchStart in stride(from: 0, to: hosts.count, by: batchSize) {
            let batch = hosts[batchStart..<min(batchStart + batchSize, hosts.count)]
            await withTaskGroup(of: LIFXDevice?.self) { group in
                for host in batch {
                    group.addTask {
                        await probeHost(host, probe: probe)
                    }
                }
                for await device in group {
                    if let device { devices.insert(device) }
                }
            }
        }
        return Array(devices)
    }

    /// Sends one GetService datagram and waits briefly for a StateService reply.
    static func probeHost(_ host: String, probe: Data, timeout: TimeInterval = 0.4) async -> LIFXDevice? {
        await withCheckedContinuation { continuation in
            guard let port = NWEndpoint.Port(rawValue: LIFXPacket.port) else {
                continuation.resume(returning: nil)
                return
            }
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: port,
                using: .udp
            )
            let lock = NSLock()
            var resumed = false

            func finish(_ value: LIFXDevice?) {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                connection.cancel()
                continuation.resume(returning: value)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: probe, completion: .contentProcessed { error in
                        if error != nil { finish(nil) }
                    })
                    connection.receiveMessage { content, _, _, _ in
                        guard let content,
                              let service = LIFXPacket.parseStateService(content),
                              service.service == 1 else {
                            finish(nil)
                            return
                        }
                        finish(LIFXDevice(serial: service.serial, host: host))
                    }
                case .failed, .cancelled:
                    finish(nil)
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .utility))
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish(nil) }
        }
    }

    /// Enumerates this machine's IPv4 interfaces (en*) and lists their /24 peers.
    static func localSubnetHosts() -> [String] {
        var addresses: [(address: UInt32, interface: String)] = []

        var ifaddrPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPointer) == 0, let first = ifaddrPointer else { return [] }
        defer { freeifaddrs(ifaddrPointer) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            guard let addr = current.pointee.ifa_addr,
                  addr.pointee.sa_family == sa_family_t(AF_INET) else { continue }
            let name = String(cString: current.pointee.ifa_name)
            guard name.hasPrefix("en") else { continue }

            let sockaddrIn = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
            let address = UInt32(bigEndian: sockaddrIn.sin_addr.s_addr)
            // Skip link-local.
            guard (address >> 16) != 0xA9FE else { continue }
            addresses.append((address, name))
        }

        var hosts: [String] = []
        for (address, _) in addresses.prefix(2) {
            let network = address & 0xFFFF_FF00
            for hostPart in UInt32(1)...254 where (network | hostPart) != address {
                let value = network | hostPart
                hosts.append(
                    "\((value >> 24) & 0xff).\((value >> 16) & 0xff).\((value >> 8) & 0xff).\(value & 0xff)"
                )
            }
        }
        return hosts
    }
}
