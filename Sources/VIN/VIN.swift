//
// VIN. (C) 2016-2023 Dr. Michael 'Mickey' Lauer <mickey@Vanille.de>
//
import Foundation

/// The Vehicle Identification Number, as standardized in ISO 3779.
public struct VIN: Equatable, Hashable {

    /// Represents the validity state of a VIN.
    public enum Validity: Equatable, Hashable {
        /// The VIN is syntactically invalid (wrong length, invalid characters).
        case invalid
        /// The VIN is syntactically valid but checksum has not been verified or is not applicable.
        case valid
        /// The VIN is syntactically valid AND has a correct checksum.
        case validWithChecksum

        /// Whether the VIN meets basic syntactic requirements.
        public var isSyntacticallyValid: Bool {
            switch self {
                case .invalid:
                    return false
                case .valid, .validWithChecksum:
                    return true
            }
        }

        /// Whether the VIN has a verified checksum.
        public var hasValidChecksum: Bool {
            switch self {
                case .validWithChecksum:
                    return true
                case .invalid, .valid:
                    return false
            }
        }
    }

    public static let NumberOfCharacters: Int = 17
    public static let AllowedCharacters: CharacterSet = .init(charactersIn: "ABCDEFGHJKLMNPRSTUVWXYZ0123456789")
    public static let Unknown: VIN = .init(content: "UNKNWN78901234567")

    /// The 17 characters as a String.
    public let content: String

    /// The validity state of the VIN.
    /// - Returns `.invalid` if the VIN doesn't meet basic ISO 3779 requirements
    /// - Returns `.validWithChecksum` if syntactically valid and checksum is correct
    /// - Returns `.valid` if syntactically valid but checksum is incorrect or not applicable
    public var validity: Validity {
        guard self.content.count == Self.NumberOfCharacters else { return .invalid }
        guard self.content.rangeOfCharacter(from: Self.AllowedCharacters.inverted) == nil else { return .invalid }

        return self.isChecksumValid ? .validWithChecksum : .valid
    }

    /// Whether the VIN is syntactically valid (has correct length and characters).
    /// This property is provided for convenience and backward compatibility.
    /// - Returns `true` if validity is `.valid` or `.validWithChecksum`, `false` otherwise
    public var isValid: Bool {
        switch self.validity {
            case .invalid:
                return false
            case .valid, .validWithChecksum:
                return true
        }
    }
    
    /// Whether the checksum digit is valid according to the VIN checksum algorithm.
    public var isChecksumValid: Bool {
        guard self.content.count == Self.NumberOfCharacters else { return false }
        
        let calculated = Self.calculateChecksum(for: self.content)
        return self.checksumDigit == calculated
    }
    
    /// Calculate the character value for checksum calculation.
    private static func characterValue(for char: Character) -> Int? {
        switch char {
        case "0"..."9":
            return Int(String(char))
        case "A", "J":
            return 1
        case "B", "K", "S":
            return 2
        case "C", "L", "T":
            return 3
        case "D", "M", "U":
            return 4
        case "E", "N", "V":
            return 5
        case "F", "W":
            return 6
        case "G", "P", "X":
            return 7
        case "H", "Y":
            return 8
        case "R", "Z":
            return 9
        default:
            return nil
        }
    }

    /// The world manufacturer identifier.
    public var wmi: String {
        guard self.isValid else { return "" }
        let index = self.content.index(self.content.startIndex, offsetBy: 3)
        let sub = self.content[..<index]
        return String(sub)
    }

    /// The world manufacturer region.
    public var wmiRegion: String {
        let wmi = self.wmi
        guard wmi != "" else { return "" }
        let index = wmi.index(self.content.startIndex, offsetBy: 1)
        let prefix = wmi[..<index]
        let fullKey = "ISO3780_WMI_REGION_\(prefix)"
        return self.computeLocalization(forKey: fullKey)
    }

    /// The world manufacturer country.
    public var wmiCountry: String {
        let wmi = self.wmi
        guard wmi != "" else { return "" }
        let index = wmi.index(self.content.startIndex, offsetBy: 2)
        let prefix = wmi[..<index]
        let fullKey = "ISO3780_WMI_COUNTRY_\(prefix)"
        return self.computeLocalization(forKey: fullKey)
    }

    // The world manufacturer manufacturer
    public var wmiManufacturer: String {
        let wmi = self.wmi
        guard wmi != "" else { return "" }
        let fullKey = "ISO3780_WMI_MANUFACTURER_\(wmi)"
        return self.computeLocalization(forKey: fullKey)
    }

    /// The vehicle descriptor section.
    public var vds: String {
        guard self.isValid else { return "" }
        let start = self.content.index(self.content.startIndex, offsetBy: 3)
        let end = self.content.index(start, offsetBy: 6)
        let sub = self.content[start..<end]
        return String(sub)
    }
    
    /// The checksum digit (9th character, part of VDS).
    /// For North American VINs, this should be a calculated check digit.
    /// Returns nil if VIN is invalid.
    public var checksumDigit: Character? {
        guard self.content.count == Self.NumberOfCharacters else { return nil }
        let index = self.content.index(self.content.startIndex, offsetBy: 8)
        return self.content[index]
    }

    /// The vehicle identification section.
    public var vis: String {
        guard self.isValid else { return "" }
        let start = self.content.index(self.content.startIndex, offsetBy: 9)
        let sub = self.content[start...]
        return String(sub)
    }

    /// Create a VIN using a `String`.
    public init(content: String) {
        self.content = content
    }

    /// Convenience method to check the validity state of a VIN string.
    public static func validity(of vin: String) -> Validity {
        VIN(content: vin).validity
    }

    /// Convenience method to check if a VIN string is syntactically valid.
    /// - Returns `true` if the VIN has correct length and characters, regardless of checksum
    public static func isValid(_ vin: String) -> Bool {
        VIN(content: vin).isValid
    }
    
    /// Propose a valid VIN based on the current VIN's data.
    /// Always returns a valid VIN by:
    /// 1. Using current data as starting point
    /// 2. Sanitizing invalid characters
    /// 3. Padding or truncating to 17 characters
    /// 4. Always applying checksum calculation (for all VINs, not just North American)
    /// 5. Creating a fantasy VIN if no valid data exists
    public func propose() -> VIN {
        // Start with current content, or empty if none
        var sanitized = self.content.uppercased()
        
        // Remove spaces
        sanitized = sanitized.replacingOccurrences(of: " ", with: "")
        
        // Replace disallowed characters with similar allowed ones
        sanitized = sanitized.replacingOccurrences(of: "I", with: "1")
        sanitized = sanitized.replacingOccurrences(of: "O", with: "0")
        sanitized = sanitized.replacingOccurrences(of: "Q", with: "0")
        
        // Remove any remaining invalid characters
        sanitized = String(sanitized.filter { Self.AllowedCharacters.contains(String($0).unicodeScalars.first!) })
        
        // If we have no valid characters at all, create a fantasy VIN
        if sanitized.isEmpty {
            // Create a fantasy but legal VIN
            // Using "1VW" as WMI (fictional Volkswagen US plant)
            // Random but plausible VDS and VIS
            sanitized = "1VWAA7A30FC000001"
        }
        
        // Ensure we have exactly 17 characters
        if sanitized.count < Self.NumberOfCharacters {
            // Pad with zeros at the end
            sanitized += String(repeating: "0", count: Self.NumberOfCharacters - sanitized.count)
        } else if sanitized.count > Self.NumberOfCharacters {
            // Truncate to 17 characters
            let index = sanitized.index(sanitized.startIndex, offsetBy: Self.NumberOfCharacters)
            sanitized = String(sanitized[..<index])
        }
        
        // Always calculate and apply the checksum (not just for North American VINs)
        sanitized = Self.fixChecksum(for: sanitized)
        
        return VIN(content: sanitized)
    }
    
    /// Calculate the correct checksum for a VIN string.
    private static func calculateChecksum(for vinString: String) -> Character? {
        guard vinString.count == Self.NumberOfCharacters else { return nil }
        
        let weights = [8, 7, 6, 5, 4, 3, 2, 10, 0, 9, 8, 7, 6, 5, 4, 3, 2]
        var sum = 0
        
        // Calculate sum for all positions except checksum position (index 8)
        for (index, char) in vinString.enumerated() {
            if index == 8 { continue } // Skip checksum position
            guard let value = Self.characterValue(for: char) else { return nil }
            sum += value * weights[index]
        }
        
        let checkDigit = sum % 11
        return checkDigit == 10 ? "X" : Character(String(checkDigit))
    }
    
    /// Fix the checksum digit for a given VIN string.
    private static func fixChecksum(for vinString: String) -> String {
        guard vinString.count == Self.NumberOfCharacters else { return vinString }
        
        guard let checksumChar = calculateChecksum(for: vinString) else { return vinString }
        
        // Replace character at position 9 (index 8) with correct checksum
        var chars = Array(vinString)
        chars[8] = checksumChar
        return String(chars)
    }
}

private extension VIN {

    func computeLocalization(forKey key: String) -> String {

        var string = NSLocalizedString(key, bundle: .module, value: "?", comment: "")
        if string != "?" { return string }

        var shorterKey = key
        shorterKey.removeLast()
        string = NSLocalizedString(shorterKey, bundle: .module, value: "?", comment: "")
        return string
    }
}

extension VIN: Identifiable {

    public var id: String { self.content }
}

extension VIN: CustomStringConvertible {

    public var description: String { self.content }

}

extension VIN: ExpressibleByStringLiteral {

    public init(stringLiteral value: StringLiteralType) {
        self = Self.init(content: value)
    }
}

extension VIN: Decodable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.content = try container.decode(String.self)
    }
}

extension VIN: Encodable {

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.content)
    }
}
