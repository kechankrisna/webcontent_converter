//
//  Page.swift
//  webcontent_converter
//
//  Created by STEVEN on 10/11/25.
//

import Foundation

// MARK: - Conversion Functions
/// Convert pixels to inches (96 DPI)
func pxToInches(_ px: Double) -> Double {
    return px / 96.0
}

/// Convert inches to pixels (96 DPI)
func inchToPx(_ inches: Double) -> Double {
    return inches * 96.0
}

/// Convert centimeters to inches
func cmToInches(_ cm: Double) -> Double {
    return pxToInches(cm / 37.8)
}

/// Convert millimeters to inches
func mmToInches(_ mm: Double) -> Double {
    return cmToInches(mm / 10.0)
}

// MARK: - PaperFormat Class
struct PaperFormat {
    let width: Double
    let height: Double
    let name: String
    
    // MARK: - Predefined Paper Sizes
    static let letter = PaperFormat.inches(name: "letter", width: 8.5, height: 11)
    static let legal = PaperFormat.inches(name: "legal", width: 8.5, height: 14)
    static let tabloid = PaperFormat.inches(name: "tabloid", width: 11, height: 17)
    static let ledger = PaperFormat.inches(name: "ledger", width: 17, height: 11)
    static let a0 = PaperFormat.inches(name: "a0", width: 33.1, height: 46.8)
    static let a1 = PaperFormat.inches(name: "a1", width: 23.4, height: 33.1)
    static let a2 = PaperFormat.inches(name: "a2", width: 16.54, height: 23.4)
    static let a3 = PaperFormat.inches(name: "a3", width: 11.7, height: 16.54)
    static let a4 = PaperFormat.inches(name: "a4", width: 8.27, height: 11.7)
    static let a5 = PaperFormat.inches(name: "a5", width: 5.83, height: 8.27)
    static let a6 = PaperFormat.inches(name: "a6", width: 4.13, height: 5.83)
    
    // MARK: - Factory Constructor from String
    /// Create PaperFormat from string value
    /// - Parameter value: Paper size string (default: "a4")
    /// - Returns: PaperFormat instance
    static func fromString(_ value: String) -> PaperFormat {
        switch value.lowercased() {
        case "letter":
            return PaperFormat.letter
        case "legal":
            return PaperFormat.legal
        case "tabloid":
            return PaperFormat.tabloid
        case "ledger":
            return PaperFormat.ledger
        case "a0":
            return PaperFormat.a0
        case "a1":
            return PaperFormat.a1
        case "a2":
            return PaperFormat.a2
        case "a3":
            return PaperFormat.a3
        case "a4":
            return PaperFormat.a4
        case "a5":
            return PaperFormat.a5
        case "a6":
            return PaperFormat.a6
        default:
            return PaperFormat.a4
        }
    }
    
    // MARK: - Factory Constructors
    /// Create PaperFormat with dimensions in inches
    static func inches(name: String = "", width: Double, height: Double) -> PaperFormat {
        return PaperFormat(width: width, height: height, name: name)
    }
    
    /// Create PaperFormat with dimensions in pixels
    static func px(name: String = "", width: Int, height: Int) -> PaperFormat {
        return PaperFormat(
            width: pxToInches(Double(width)),
            height: pxToInches(Double(height)),
            name: name
        )
    }
    
    /// Create PaperFormat with dimensions in centimeters
    static func cm(name: String = "", width: Double, height: Double) -> PaperFormat {
        return PaperFormat(
            width: cmToInches(width),
            height: cmToInches(height),
            name: name
        )
    }
    
    /// Create PaperFormat with dimensions in millimeters
    static func mm(name: String = "", width: Double, height: Double) -> PaperFormat {
        return PaperFormat(
            width: mmToInches(width),
            height: mmToInches(height),
            name: name
        )
    }
    
    // MARK: - Utility Methods
    /// Convert to dictionary for serialization
    func toMap() -> [String: Any] {
        return [
            "name": name,
            "width": width,
            "height": height
        ]
    }
    
    /// Get width in pixels (96 DPI)
    var widthPixels: Int {
        return Int(inchToPx(width))
    }
    
    /// Get height in pixels (96 DPI)
    var heightPixels: Int {
        return Int(inchToPx(height))
    }
}

// MARK: - CustomStringConvertible
extension PaperFormat: CustomStringConvertible {
    var description: String {
        return "PaperFormat.inches(width: \(width), height: \(height))"
    }
}

// MARK: - PdfMargins Class
struct PdfMargins {
    var top: Double
    var bottom: Double
    var left: Double
    var right: Double
    
    // MARK: - Static Constants
    static let zero = PdfMargins()
    
    // MARK: - Initializers
    init(top: Double = 0, bottom: Double = 0, left: Double = 0, right: Double = 0) {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
    }
    
    /// Create margins with dimensions in inches
    static func inches(top: Double = 0, bottom: Double = 0, left: Double = 0, right: Double = 0) -> PdfMargins {
        return PdfMargins(top: top, bottom: bottom, left: left, right: right)
    }
    
    /// Create margins with dimensions in pixels
    static func px(top: Int = 0, bottom: Int = 0, left: Int = 0, right: Int = 0) -> PdfMargins {
        return PdfMargins(
            top: pxToInches(Double(top)),
            bottom: pxToInches(Double(bottom)),
            left: pxToInches(Double(left)),
            right: pxToInches(Double(right))
        )
    }
    
    /// Create margins with dimensions in centimeters
    static func cm(top: Double = 0, bottom: Double = 0, left: Double = 0, right: Double = 0) -> PdfMargins {
        return PdfMargins(
            top: cmToInches(top),
            bottom: cmToInches(bottom),
            left: cmToInches(left),
            right: cmToInches(right)
        )
    }
    
    /// Create margins with dimensions in millimeters
    static func mm(top: Double = 0, bottom: Double = 0, left: Double = 0, right: Double = 0) -> PdfMargins {
        return PdfMargins(
            top: mmToInches(top),
            bottom: mmToInches(bottom),
            left: mmToInches(left),
            right: mmToInches(right)
        )
    }
    
    // MARK: - Utility Methods
    /// Convert to dictionary for serialization
    func toMap() -> [String: Double] {
        return [
            "top": top,
            "bottom": bottom,
            "left": left,
            "right": right
        ]
    }
}

// MARK: - CustomStringConvertible
extension PdfMargins: CustomStringConvertible {
    var description: String {
        return "PdfMargins.inches(top: \(top), bottom: \(bottom), left: \(left), right: \(right))"
    }
}
