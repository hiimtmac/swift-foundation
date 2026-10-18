//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing
import NewCodable

@Suite("Malformed Unicode escape diagnostics")
struct JSONUnicodeEscapeDiagnosticTests {
    @Test(arguments: [
        // Valid UTF-8, but not four hexadecimal digits after the escape marker.
        [UInt8](arrayLiteral: 0x22, 0x5c, 0x75, 0xc3, 0xa9, 0x22),
        // Invalid UTF-8 must also produce a decoding error, not a trap.
        [UInt8](arrayLiteral: 0x22, 0x5c, 0x75, 0xff, 0x22),
    ])
    func rejectsMinimalReproducers(bytes: [UInt8]) {
        #expect(throws: CodingError.Decoding.self) {
            try NewJSONDecoder().decode(String.self, from: bytes.span.bytes)
        }
    }

    @Test func rejectsNonASCIIAtEveryHexPosition() {
        for position in 0..<4 {
            for byte in UInt8(0x80)...UInt8(0xff) {
                var bytes: [UInt8] = [0x22, 0x5c, 0x75]
                bytes.append(contentsOf: repeatElement(UInt8(0x30), count: position))
                bytes.append(byte)
                bytes.append(contentsOf: repeatElement(UInt8(0x30), count: 3 - position))
                bytes.append(0x22)
                #expect(throws: CodingError.Decoding.self) {
                    try NewJSONDecoder().decode(String.self, from: bytes.span.bytes)
                }
            }
        }
    }

    @Test func rejectsMalformedLowSurrogateEscape() {
        var bytes = Array(#""\uD834\u"#.utf8)
        bytes.append(contentsOf: [0xc3, 0xa9, 0x22])
        #expect(throws: CodingError.Decoding.self) {
            try NewJSONDecoder().decode(String.self, from: bytes.span.bytes)
        }
    }

    @Test func preservesASCIIDiagnostic() {
        let bytes = Array(#""\ug000""#.utf8)
        let error = #expect(throws: CodingError.Decoding.self) {
            try NewJSONDecoder().decode(String.self, from: bytes.span.bytes)
        }
        #expect(error?.userDebugDescription == "Invalid hex sequence 'g'")
    }

    @Test(arguments: [
        (#""\u00e9""#, "é"),
        (#""\u00E9""#, "é"),
        (#""\uD834\uDD1E""#, "𝄞"),
    ])
    func preservesValidEscapes(json: String, expected: String) throws {
        let bytes = Array(json.utf8)
        #expect(try NewJSONDecoder().decode(String.self, from: bytes.span.bytes) == expected)
    }
}
