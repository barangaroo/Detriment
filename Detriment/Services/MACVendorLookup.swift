import Foundation

/// Looks up device manufacturer from MAC address prefix (OUI).
/// Bundled database — no network calls needed.
struct MACVendorLookup {

    func lookup(mac: String) -> String? {
        let prefix = mac.prefix(8).uppercased().replacingOccurrences(of: "-", with: ":")
        return oui[prefix]
    }

    // Top ~150 most common OUI prefixes for home/consumer devices
    // Full database: https://standards-oui.ieee.org
    private let oui: [String: String] = [
        // Apple
        "AC:DE:48": "Apple",
        "A8:66:7F": "Apple",
        "3C:22:FB": "Apple",
        "F0:18:98": "Apple",
        "14:7D:DA": "Apple",
        "6C:94:66": "Apple",
        "DC:2B:2A": "Apple",
        "A4:B1:C1": "Apple",
        "F4:5C:89": "Apple",
        "78:7B:8A": "Apple",

        // Samsung
        "8C:F5:A3": "Samsung",
        "CC:07:AB": "Samsung",
        "50:01:D9": "Samsung",
        "E4:7C:F9": "Samsung",
        "AC:5F:3E": "Samsung",
        "BC:72:B1": "Samsung",

        // Google / Nest
        "F4:F5:D8": "Google",
        "54:60:09": "Google",
        "A4:77:33": "Google",
        "30:FD:38": "Google",
        "48:D6:D5": "Google Nest",

        // Amazon (Echo, Fire, Ring)
        "74:C2:46": "Amazon",
        "FC:65:DE": "Amazon",
        "A0:02:DC": "Amazon",
        "44:00:49": "Amazon",
        "68:54:FD": "Amazon Ring",
        "34:D2:70": "Amazon",

        // Microsoft / Xbox
        "DC:B4:C4": "Microsoft",
        "C8:3F:26": "Microsoft",
        "7C:ED:8D": "Microsoft",
        "28:18:78": "Microsoft Xbox",

        // Sony / PlayStation
        "FC:F8:AE": "Sony",
        "A8:E3:EE": "Sony PlayStation",
        "00:D9:D1": "Sony PlayStation",
        "70:9E:29": "Sony PlayStation",

        // Nintendo
        "7C:BB:8A": "Nintendo",
        "98:B6:E9": "Nintendo",
        "B8:AE:ED": "Nintendo",

        // Router manufacturers
        "C0:06:C3": "TP-Link",
        "50:C7:BF": "TP-Link",
        "60:32:B1": "TP-Link",
        "14:EB:B6": "TP-Link",
        "B0:BE:76": "TP-Link",
        "C4:E9:84": "TP-Link",
        "30:B5:C2": "TP-Link",
        "04:D9:F5": "ASUS",
        "1C:87:2C": "ASUS",
        "AC:9E:17": "ASUS",
        "2C:FD:A1": "ASUS",
        "E0:46:9A": "Netgear",
        "A4:2B:8C": "Netgear",
        "6C:B0:CE": "Netgear",
        "C4:04:15": "Netgear",
        "20:AA:4B": "Cisco/Linksys",
        "C0:56:27": "Cisco/Linksys",
        "E8:65:D4": "Cisco/Linksys",
        "B4:FB:E4": "Ubiquiti",
        "78:8A:20": "Ubiquiti",
        "FC:EC:DA": "Ubiquiti",
        "24:5A:4C": "Ubiquiti",
        "18:E8:29": "Ubiquiti",
        "74:AC:B9": "Ubiquiti",
        "44:D9:E7": "Ubiquiti",

        // Sonos
        "5C:AA:FD": "Sonos",
        "00:0E:58": "Sonos",
        "94:9F:3E": "Sonos",
        "B8:E9:37": "Sonos",
        "48:A6:B8": "Sonos",

        // Roku
        "DC:3A:5E": "Roku",
        "B0:A7:37": "Roku",
        "CC:6D:A0": "Roku",

        // Cameras
        "2C:AA:8E": "Wyze",
        "7C:78:B2": "Wyze",
        "D0:3F:27": "Ring",
        "28:6D:97": "Hikvision",
        "C0:56:E3": "Hikvision",
        "44:19:B6": "Hikvision",
        "54:C4:15": "Reolink",

        // Smart home / IoT
        "D8:F1:5B": "Espressif (IoT)",
        "24:0A:C4": "Espressif (IoT)",
        "CC:50:E3": "Espressif (IoT)",
        "A4:CF:12": "Espressif (IoT)",
        "60:01:94": "Espressif (IoT)",
        "B4:E6:2D": "Espressif (IoT)",
        "30:AE:A4": "Espressif (IoT)",
        "68:C6:3A": "Espressif (IoT)",
        "D8:BF:C0": "Espressif (IoT)",
        "3C:71:BF": "Espressif (IoT)",
        "7C:DF:A1": "Espressif (IoT)",
        "AC:67:B2": "Espressif (IoT)",
        "08:3A:F2": "Espressif (IoT)",
        "48:3F:DA": "Espressif (IoT)",
        "84:0D:8E": "Espressif (IoT)",
        "D4:8A:FC": "Tuya (IoT)",
        "10:D5:61": "Tuya (IoT)",

        // HP / Printers
        "3C:D9:2B": "HP",
        "9C:B6:D0": "HP",
        "80:CE:62": "HP",
        "10:1F:74": "HP",

        // Epson / Canon / Brother
        "00:26:AB": "Epson",
        "AC:18:26": "Epson",
        "64:EB:8C": "Canon",
        "30:D1:6B": "Brother",

        // LG
        "C4:36:6C": "LG",
        "CC:2D:8C": "LG",
        "A8:23:FE": "LG",

        // Philips / Hue
        "00:17:88": "Philips Hue",
        "EC:B5:FA": "Philips Hue",

        // Intel (many laptops/desktops)
        "5C:87:9C": "Intel",
        "48:51:B7": "Intel",
        "34:13:E8": "Intel",

        // Raspberry Pi
        "B8:27:EB": "Raspberry Pi",
        "DC:A6:32": "Raspberry Pi",
        "E4:5F:01": "Raspberry Pi",
    ]
}
