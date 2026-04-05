import Foundation
import BackgroundTasks

final class BackgroundScanner {
    static let shared = BackgroundScanner()
    static let taskIdentifier = "com.detriment.app.networkscan"

    private init() {}

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            self.handleBackgroundScan(task: task)
        }
    }

    func scheduleBackgroundScan() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 min
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background scan: \(error)")
        }
    }

    private func handleBackgroundScan(task: BGAppRefreshTask) {
        // Schedule the next scan
        scheduleBackgroundScan()

        let scanner = BackgroundNetworkProbe()

        task.expirationHandler = {
            scanner.cancel()
        }

        scanner.quickScan { newDevices in
            if !newDevices.isEmpty {
                if newDevices.count == 1 {
                    NotificationManager.shared.notifyNewDevice(newDevices[0])
                } else {
                    NotificationManager.shared.notifyMultipleNewDevices(count: newDevices.count)
                }

                let stored = newDevices.map { StoredDevice(from: $0, isNew: true) }
                DeviceStorage.shared.saveNewDevices(stored)
            }

            task.setTaskCompleted(success: true)
        }
    }
}

/// Lightweight scanner for background use — faster, fewer ports
final class BackgroundNetworkProbe {
    private var isCancelled = false
    private let macLookup = MACVendorLookup()

    func cancel() { isCancelled = true }

    func quickScan(completion: @escaping ([NetworkDevice]) -> Void) {
        Task {
            let subnet = getSubnet()
            var newDevices: [NetworkDevice] = []
            let storage = DeviceStorage.shared

            // Ping sweep only — no port scan in background to save time
            await withTaskGroup(of: NetworkDevice?.self) { group in
                for i in 1...254 {
                    guard !isCancelled else { break }
                    group.addTask {
                        let ip = "\(subnet).\(i)"
                        guard await self.quickPing(ip) else { return nil }
                        let mac = ARPCache.shared.lookup(ip: ip)
                        let manufacturer = mac.flatMap { self.macLookup.lookup(mac: $0) }

                        return NetworkDevice(
                            ipAddress: ip,
                            macAddress: mac,
                            hostname: nil,
                            manufacturer: manufacturer,
                            deviceType: .unknown,
                            openPorts: [],
                            isReachable: true,
                            lastSeen: Date(),
                            riskLevel: .low
                        )
                    }
                }

                for await device in group {
                    if let device = device, let mac = device.macAddress {
                        if storage.isNewDevice(mac: mac) {
                            newDevices.append(device)
                        }
                    }
                }
            }

            completion(newDevices)
        }
    }

    private func getSubnet() -> String {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return "192.168.1" }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let addr = ptr.pointee
            guard addr.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: addr.ifa_name)
            guard name == "en0" else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(addr.ifa_addr, socklen_t(addr.ifa_addr.pointee.sa_len),
                           &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                let ip = String(cString: hostname)
                let parts = ip.split(separator: ".")
                if parts.count == 4 { return parts[0...2].joined(separator: ".") }
            }
        }
        return "192.168.1"
    }

    private func quickPing(_ ip: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(ip), port: 80, using: .tcp)
            let queue = DispatchQueue(label: "bg.ping.\(ip)")
            var resolved = false

            connection.stateUpdateHandler = { state in
                guard !resolved else { return }
                switch state {
                case .ready:
                    resolved = true
                    connection.cancel()
                    continuation.resume(returning: true)
                case .failed, .cancelled:
                    resolved = true
                    connection.cancel()
                    continuation.resume(returning: false)
                default: break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 0.5) {
                guard !resolved else { return }
                resolved = true
                connection.cancel()
                continuation.resume(returning: false)
            }
        }
    }
}

import Network
