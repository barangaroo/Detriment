import Foundation
import Network
import WidgetKit

@MainActor
final class NetworkScanner: ObservableObject {
    @Published var devices: [NetworkDevice] = []
    @Published var wifiInfo: WiFiInfo?
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var detrimentScore: DetrimentScore?
    @Published var deviceIntel: [String: DeviceIntel] = [:] // MAC prefix → intel

    private let macLookup = MACVendorLookup()
    private var scanTask: Task<Void, Never>?

    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0
        devices = []
        detrimentScore = nil

        scanTask = Task {
            await loadWiFiInfo()

            #if targetEnvironment(simulator)
            await simulateScan()
            #else
            let subnet = getSubnet()
            await scanSubnet(subnet)
            #endif

            // Enrich with backend intelligence
            await enrichFromAPI()

            calculateDetrimentScore()
            isScanning = false
        }
    }

    func stopScan() {
        scanTask?.cancel()
        isScanning = false
    }

    // MARK: - WiFi Info

    private func loadWiFiInfo() async {
        // Get current WiFi info via NEHotspotNetwork or CNCopyCurrentNetworkInfo
        // For now, use basic info available without special entitlements
        wifiInfo = WiFiInfo(
            ssid: getCurrentSSID(),
            bssid: nil,
            security: .wpa2, // Default assumption
            signalStrength: nil
        )
    }

    private func getCurrentSSID() -> String? {
        // On iOS 16+, we need NEHotspotNetwork for SSID
        // This requires the Access WiFi Information entitlement
        return nil // Will be populated by NEHotspotNetwork
    }

    // MARK: - Subnet Discovery

    private func getSubnet() -> String {
        var subnet = "192.168.1"

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return subnet
        }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let addr = ptr.pointee
            guard addr.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }

            let name = String(cString: addr.ifa_name)
            guard name == "en0" else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                addr.ifa_addr, socklen_t(addr.ifa_addr.pointee.sa_len),
                &hostname, socklen_t(hostname.count),
                nil, 0, NI_NUMERICHOST
            ) == 0 {
                let ip = String(cString: hostname)
                let components = ip.split(separator: ".")
                if components.count == 4 {
                    subnet = components[0...2].joined(separator: ".")
                }
            }
        }

        return subnet
    }

    func getLocalIPAddress() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let addr = ptr.pointee
            guard addr.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: addr.ifa_name)
            guard name == "en0" else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                addr.ifa_addr, socklen_t(addr.ifa_addr.pointee.sa_len),
                &hostname, socklen_t(hostname.count),
                nil, 0, NI_NUMERICHOST
            ) == 0 {
                return String(cString: hostname)
            }
        }
        return nil
    }

    // MARK: - Subnet Scan

    private func scanSubnet(_ subnet: String) async {
        let total = 254
        var found: [NetworkDevice] = []

        await withTaskGroup(of: NetworkDevice?.self) { group in
            for i in 1...254 {
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    let ip = "\(subnet).\(i)"
                    return await self.probeHost(ip)
                }
            }

            var completed = 0
            for await result in group {
                completed += 1
                scanProgress = Double(completed) / Double(total)

                if let device = result {
                    found.append(device)
                    devices = found.sorted { $0.ipAddress.localizedStandardCompare($1.ipAddress) == .orderedAscending }
                }
            }
        }
    }

    // MARK: - Host Probing

    private func probeHost(_ ip: String) async -> NetworkDevice? {
        let reachable = await ping(ip)
        guard reachable else { return nil }

        let hostname = await resolveHostname(ip)
        let macAddress = await getMACAddress(ip)
        let manufacturer = macAddress.flatMap { macLookup.lookup(mac: $0) }
        let openPorts = await scanPorts(ip)
        let deviceType = inferDeviceType(hostname: hostname, manufacturer: manufacturer, openPorts: openPorts)
        let riskLevel = assessRisk(openPorts: openPorts, deviceType: deviceType, manufacturer: manufacturer)

        return NetworkDevice(
            ipAddress: ip,
            macAddress: macAddress,
            hostname: hostname,
            manufacturer: manufacturer,
            deviceType: deviceType,
            openPorts: openPorts,
            isReachable: true,
            lastSeen: Date(),
            riskLevel: riskLevel
        )
    }

    // MARK: - Ping

    private func ping(_ ip: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let host = NWEndpoint.Host(ip)
            let connection = NWConnection(host: host, port: 80, using: .tcp)

            let queue = DispatchQueue(label: "ping.\(ip)")
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
                default:
                    break
                }
            }

            connection.start(queue: queue)

            queue.asyncAfter(deadline: .now() + 1.0) {
                guard !resolved else { return }
                resolved = true
                connection.cancel()
                continuation.resume(returning: false)
            }
        }
    }

    // MARK: - Hostname Resolution

    private func resolveHostname(_ ip: String) async -> String? {
        await withCheckedContinuation { continuation in
            var hints = addrinfo()
            hints.ai_family = AF_INET
            hints.ai_flags = AI_NUMERICHOST

            var sa = sockaddr_in()
            sa.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            sa.sin_family = sa_family_t(AF_INET)
            inet_pton(AF_INET, ip, &sa.sin_addr)

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))

            let result = withUnsafePointer(to: &sa) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    getnameinfo(
                        sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size),
                        &hostname, socklen_t(hostname.count),
                        nil, 0, 0
                    )
                }
            }

            if result == 0 {
                let name = String(cString: hostname)
                if name != ip {
                    continuation.resume(returning: name)
                } else {
                    continuation.resume(returning: nil)
                }
            } else {
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - MAC Address (ARP Cache)

    private func getMACAddress(_ ip: String) async -> String? {
        // Read from ARP cache via sysctl
        // This is how Fing and similar apps get MAC addresses on iOS
        return ARPCache.shared.lookup(ip: ip)
    }

    // MARK: - Port Scanning

    private func scanPorts(_ ip: String) async -> [PortInfo] {
        var results: [PortInfo] = []

        await withTaskGroup(of: PortInfo?.self) { group in
            for (port, service, risk) in PortInfo.commonPorts {
                group.addTask {
                    let isOpen = await self.checkPort(ip, port: UInt16(port))
                    guard isOpen else { return nil }
                    return PortInfo(port: port, service: service, isOpen: true, risk: risk)
                }
            }

            for await result in group {
                if let portInfo = result {
                    results.append(portInfo)
                }
            }
        }

        return results.sorted { $0.port < $1.port }
    }

    private func checkPort(_ ip: String, port: UInt16) async -> Bool {
        await withCheckedContinuation { continuation in
            let host = NWEndpoint.Host(ip)
            let nwPort = NWEndpoint.Port(rawValue: port)!
            let connection = NWConnection(host: host, port: nwPort, using: .tcp)

            let queue = DispatchQueue(label: "port.\(ip).\(port)")
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
                default:
                    break
                }
            }

            connection.start(queue: queue)

            queue.asyncAfter(deadline: .now() + 0.8) {
                guard !resolved else { return }
                resolved = true
                connection.cancel()
                continuation.resume(returning: false)
            }
        }
    }

    // MARK: - Device Type Inference

    private func inferDeviceType(hostname: String?, manufacturer: String?, openPorts: [PortInfo]) -> DeviceType {
        let name = (hostname ?? "").lowercased()
        let mfr = (manufacturer ?? "").lowercased()

        // Router detection
        if name.contains("gateway") || name.contains("router") ||
           mfr.contains("netgear") || mfr.contains("tp-link") || mfr.contains("asus") ||
           mfr.contains("linksys") || mfr.contains("ubiquiti") || mfr.contains("cisco") {
            return .router
        }

        // Apple devices
        if name.contains("iphone") || mfr.contains("apple") && openPorts.contains(where: { $0.port == 62078 }) {
            return .phone
        }
        if name.contains("ipad") {
            return .tablet
        }
        if name.contains("macbook") || name.contains("imac") || name.contains("mac-") {
            return .computer
        }

        // Smart TV
        if name.contains("tv") || name.contains("roku") || name.contains("firestick") ||
           mfr.contains("samsung") || mfr.contains("lg electronics") || mfr.contains("roku") ||
           mfr.contains("amazon") {
            return .tv
        }

        // Speakers
        if name.contains("homepod") || name.contains("echo") || name.contains("sonos") ||
           mfr.contains("sonos") {
            return .speaker
        }

        // Cameras
        if name.contains("camera") || name.contains("cam") || mfr.contains("ring") ||
           mfr.contains("nest") || mfr.contains("wyze") || mfr.contains("hikvision") ||
           openPorts.contains(where: { $0.port == 554 }) {
            return .camera
        }

        // Printers
        if name.contains("printer") || mfr.contains("hp") || mfr.contains("epson") ||
           mfr.contains("brother") || mfr.contains("canon") ||
           openPorts.contains(where: { $0.port == 9100 }) {
            return .printer
        }

        // Game consoles
        if name.contains("playstation") || name.contains("xbox") || name.contains("nintendo") ||
           mfr.contains("sony") || mfr.contains("microsoft") || mfr.contains("nintendo") {
            return .gameConsole
        }

        // Computers (generic)
        if openPorts.contains(where: { $0.port == 22 || $0.port == 445 || $0.port == 3389 }) {
            return .computer
        }

        // IoT catch-all
        if mfr.contains("espressif") || mfr.contains("tuya") || mfr.contains("shenzhen") {
            return .iotDevice
        }

        return .unknown
    }

    // MARK: - Risk Assessment

    private func assessRisk(openPorts: [PortInfo], deviceType: DeviceType, manufacturer: String?) -> RiskLevel {
        var maxRisk = RiskLevel.safe

        for port in openPorts {
            if port.risk > maxRisk {
                maxRisk = port.risk
            }
        }

        // Unknown devices are inherently riskier
        if deviceType == .unknown {
            maxRisk = max(maxRisk, .medium)
        }

        // Cameras with open RTSP are high risk
        if deviceType == .camera && openPorts.contains(where: { $0.port == 554 }) {
            maxRisk = max(maxRisk, .high)
        }

        return maxRisk
    }

    // MARK: - Detriment Score

    private func calculateDetrimentScore() {
        let unknownCount = devices.filter { $0.deviceType == .unknown }.count
        let highRiskPorts = devices.flatMap { $0.openPorts }.filter { $0.risk >= .high }.count
        let riskyDevices = devices.filter { $0.riskLevel >= .medium }.count

        let networkSecScore = min(25, (wifiInfo?.securityRisk.rawValue ?? 2) * 8)
        let unknownScore = min(25, unknownCount * 10)
        let portScore = min(25, highRiskPorts * 5)
        let deviceScore = min(25, riskyDevices * 8)

        let total = min(100, networkSecScore + unknownScore + portScore + deviceScore)

        detrimentScore = DetrimentScore(
            total: total,
            networkSecurity: networkSecScore,
            unknownDevices: unknownScore,
            openPorts: portScore,
            vulnerableDevices: deviceScore
        )

        // Save for widget and detect new devices
        saveResultsForWidget()
    }

    // MARK: - API Enrichment

    private func enrichFromAPI() async {
        let intel = await APIClient.shared.lookupDevices(devices)

        for item in intel {
            deviceIntel[item.mac_prefix] = item

            // Update device info with backend data
            if let index = devices.firstIndex(where: {
                guard let mac = $0.macAddress else { return false }
                return mac.prefix(8).uppercased() == item.mac_prefix.uppercased()
            }) {
                // Use backend manufacturer if local one is missing
                if devices[index].manufacturer == nil, let mfr = item.manufacturer {
                    devices[index].manufacturer = mfr
                }

                // Use backend device type if we couldn't determine it
                if devices[index].deviceType == .unknown, let dt = item.device_type {
                    if let deviceType = DeviceType(rawValue: dt.capitalized) {
                        devices[index].deviceType = deviceType
                    }
                }
            }
        }

        // Submit anonymized report for crowdsourced data
        Task {
            await APIClient.shared.reportScan(devices)
        }
    }

    /// Get backend intel for a specific device
    func getIntel(for device: NetworkDevice) -> DeviceIntel? {
        guard let mac = device.macAddress else { return nil }
        let prefix = String(mac.prefix(8)).uppercased()
        return deviceIntel[prefix]
    }

    // MARK: - Widget & Notifications

    private func saveResultsForWidget() {
        let storage = DeviceStorage.shared
        var newDevices: [NetworkDevice] = []

        let storedDevices = devices.map { device -> StoredDevice in
            let isNew: Bool
            if let mac = device.macAddress {
                isNew = storage.isNewDevice(mac: mac)
                if isNew { newDevices.append(device) }
                storage.markAsKnown(mac)
            } else {
                isNew = false
            }
            return StoredDevice(from: device, isNew: isNew)
        }

        storage.saveLastScan(devices: storedDevices)

        if let score = detrimentScore {
            storage.saveScore(score.total, grade: score.grade)
        }

        // Notify about new devices
        if !newDevices.isEmpty {
            let storedNew = newDevices.map { StoredDevice(from: $0, isNew: true) }
            storage.saveNewDevices(storedNew)

            for device in newDevices {
                NotificationManager.shared.notifyNewDevice(device)
            }
        }

        // Refresh widget
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Simulator Mock Data

    #if targetEnvironment(simulator)
    private func simulateScan() async {
        let mockDevices: [(String, String, String?, String?, DeviceType, [PortInfo], RiskLevel)] = [
            ("192.168.1.1", "C0:06:C3:AA:BB:CC", "TP-Link Archer AX73", "TP-Link", .router,
             [PortInfo(port: 80, service: "HTTP", isOpen: true, risk: .low),
              PortInfo(port: 443, service: "HTTPS", isOpen: true, risk: .safe)], .low),

            ("192.168.1.2", "3C:22:FB:11:22:33", "Jasons-MacBook-Pro", "Apple", .computer,
             [PortInfo(port: 22, service: "SSH", isOpen: true, risk: .medium),
              PortInfo(port: 5000, service: "UPnP", isOpen: true, risk: .medium)], .medium),

            ("192.168.1.3", "8C:F5:A3:44:55:66", "Galaxy-S24", "Samsung", .phone, [], .safe),

            ("192.168.1.5", "5C:AA:FD:77:88:99", "Sonos-Living-Room", "Sonos", .speaker,
             [PortInfo(port: 443, service: "HTTPS", isOpen: true, risk: .safe),
              PortInfo(port: 1443, service: "Sonos", isOpen: true, risk: .low)], .safe),

            ("192.168.1.7", "28:6D:97:AA:BB:CC", nil, "Hikvision", .camera,
             [PortInfo(port: 80, service: "HTTP", isOpen: true, risk: .low),
              PortInfo(port: 554, service: "RTSP", isOpen: true, risk: .high),
              PortInfo(port: 8080, service: "HTTP Proxy", isOpen: true, risk: .medium)], .high),

            ("192.168.1.9", "D8:F1:5B:DD:EE:FF", nil, "Espressif (IoT)", .iotDevice,
             [PortInfo(port: 80, service: "HTTP", isOpen: true, risk: .low)], .medium),

            ("192.168.1.12", "74:C2:46:11:22:33", "Echo-Dot-Kitchen", "Amazon", .speaker,
             [PortInfo(port: 443, service: "HTTPS", isOpen: true, risk: .safe),
              PortInfo(port: 8443, service: "HTTPS Alt", isOpen: true, risk: .low)], .safe),

            ("192.168.1.14", "A8:E3:EE:44:55:66", "PS5-Living-Room", "Sony PlayStation", .gameConsole, [], .safe),

            ("192.168.1.18", "00:00:00:00:00:00", nil, nil, .unknown,
             [PortInfo(port: 23, service: "Telnet", isOpen: true, risk: .critical),
              PortInfo(port: 80, service: "HTTP", isOpen: true, risk: .low)], .critical),

            ("192.168.1.20", "3C:D9:2B:AA:BB:CC", "HP-LaserJet-Pro", "HP", .printer,
             [PortInfo(port: 80, service: "HTTP", isOpen: true, risk: .low),
              PortInfo(port: 443, service: "HTTPS", isOpen: true, risk: .safe),
              PortInfo(port: 9100, service: "Printer", isOpen: true, risk: .low)], .low),

            ("192.168.1.23", "DC:3A:5E:DD:EE:FF", "Roku-Bedroom", "Roku", .tv,
             [PortInfo(port: 8060, service: "Roku API", isOpen: true, risk: .low)], .safe),

            ("192.168.1.30", "B4:FB:E4:11:22:33", "UniFi-AP", "Ubiquiti", .router,
             [PortInfo(port: 22, service: "SSH", isOpen: true, risk: .medium),
              PortInfo(port: 443, service: "HTTPS", isOpen: true, risk: .safe)], .low),
        ]

        let total = mockDevices.count
        for (index, mock) in mockDevices.enumerated() {
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s delay per device

            let device = NetworkDevice(
                ipAddress: mock.0,
                macAddress: mock.1 == "00:00:00:00:00:00" ? nil : mock.1,
                hostname: mock.2,
                manufacturer: mock.3,
                deviceType: mock.4,
                openPorts: mock.5,
                isReachable: true,
                lastSeen: Date(),
                riskLevel: mock.6
            )
            devices.append(device)
            scanProgress = Double(index + 1) / Double(total)
        }
    }
    #endif
}
