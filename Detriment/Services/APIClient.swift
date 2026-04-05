import Foundation

final class APIClient {
    static let shared = APIClient()

    #if DEBUG
    private var baseURL = "http://localhost:8000"
    #else
    private var baseURL = "https://api.detriment.ai"
    #endif

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    // MARK: - Batch Lookup

    func lookupDevices(_ devices: [NetworkDevice]) async -> [DeviceIntel] {
        let requestDevices = devices.compactMap { device -> LookupRequestDevice? in
            guard let mac = device.macAddress else { return nil }
            let prefix = String(mac.prefix(8))
            let ports = device.openPorts.map { $0.port }
            return LookupRequestDevice(mac_prefix: prefix, open_ports: ports)
        }

        guard !requestDevices.isEmpty else { return [] }

        let body = BatchLookupRequest(devices: requestDevices)

        guard let url = URL(string: "\(baseURL)/api/lookup/batch") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }

            let result = try decoder.decode(BatchLookupResponse.self, from: data)
            return result.devices
        } catch {
            print("API lookup failed: \(error)")
            return []
        }
    }

    // MARK: - Report Scan (anonymized)

    func reportScan(_ devices: [NetworkDevice], region: String? = nil) async {
        let requestDevices = devices.compactMap { device -> LookupRequestDevice? in
            guard let mac = device.macAddress else { return nil }
            let prefix = String(mac.prefix(8))
            let ports = device.openPorts.map { $0.port }
            return LookupRequestDevice(mac_prefix: prefix, open_ports: ports)
        }

        guard !requestDevices.isEmpty else { return }

        let body = ScanReportBody(devices: requestDevices, region: region)

        guard let url = URL(string: "\(baseURL)/api/report") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let _ = try await session.data(for: request)
        } catch {
            print("Report failed: \(error)")
        }
    }
}

// MARK: - API Models

struct LookupRequestDevice: Codable {
    let mac_prefix: String
    let open_ports: [Int]
}

struct BatchLookupRequest: Codable {
    let devices: [LookupRequestDevice]
}

struct BatchLookupResponse: Codable {
    let devices: [DeviceIntel]
}

struct DeviceIntel: Codable, Identifiable {
    var id: String { mac_prefix }
    let mac_prefix: String
    let manufacturer: String?
    let device_type: String?
    let device_model: String?
    let device_description: String?
    let risk_score: Int
    let ports: [PortIntel]
    let vulnerabilities: [VulnIntel]
    let tips: [String]
}

struct PortIntel: Codable {
    let port: Int
    let service_name: String
    let risk_level: String
    let description: String
    let what_to_do: String?
}

struct VulnIntel: Codable, Identifiable {
    var id: String { title }
    let title: String
    let severity: String
    let description: String
    let fix: String?
}

struct ScanReportBody: Codable {
    let devices: [LookupRequestDevice]
    let region: String?
}
