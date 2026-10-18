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

@Suite("Integer overflow recovery")
struct JSONIntegerOverflowRecoveryTests {
    private func checkBounds<T: FixedWidthInteger & JSONDecodable>(
        _ type: T.Type, aboveMaximum: String, belowMinimum: String? = nil
    ) throws {
        let decoder = NewJSONDecoder()
        for value in [T.min, T.max] {
            let bytes = Array(String(value).utf8)
            #expect(try decoder.decode(T.self, from: bytes.span.bytes) == value)
        }
        for number in [aboveMaximum, belowMinimum].compactMap({ $0 }) {
            // EOF, whitespace, array close/comma and object close/comma must all terminate.
            for suffix in ["", " ", "\n"] {
                let bytes = Array((number + suffix).utf8)
                #expect(throws: CodingError.Decoding.self) {
                    try decoder.decode(T.self, from: bytes.span.bytes)
                }
            }
            for json in ["[\(number)]", "[\(number),0]"] {
                let bytes = Array(json.utf8)
                #expect(throws: CodingError.Decoding.self) {
                    try decoder.decode([T].self, from: bytes.span.bytes)
                }
            }
            for json in ["{\"value\":\(number)}", "{\"value\":\(number),\"other\":0}"] {
                let bytes = Array(json.utf8)
                #expect(throws: CodingError.Decoding.self) {
                    try decoder.decode([String: T].self, from: bytes.span.bytes)
                }
            }
        }
    }

    @Test func signedIntegerBoundaries() throws {
        try checkBounds(Int8.self, aboveMaximum: "128", belowMinimum: "-129")
        try checkBounds(Int16.self, aboveMaximum: "32768", belowMinimum: "-32769")
        try checkBounds(Int32.self, aboveMaximum: "2147483648", belowMinimum: "-2147483649")
        try checkBounds(Int64.self, aboveMaximum: "9223372036854775808", belowMinimum: "-9223372036854775809")
        try checkBounds(Int128.self, aboveMaximum: "170141183460469231731687303715884105728", belowMinimum: "-170141183460469231731687303715884105729")
        // A decimal zero suffix is out of range on either 32-bit or 64-bit hosts.
        try checkBounds(Int.self, aboveMaximum: String(Int.max) + "0", belowMinimum: String(Int.min) + "0")
    }

    @Test func unsignedIntegerBoundaries() throws {
        try checkBounds(UInt8.self, aboveMaximum: "256")
        try checkBounds(UInt16.self, aboveMaximum: "65536")
        try checkBounds(UInt32.self, aboveMaximum: "4294967296")
        try checkBounds(UInt64.self, aboveMaximum: "18446744073709551616")
        try checkBounds(UInt128.self, aboveMaximum: "340282366920938463463374607431768211456")
        try checkBounds(UInt.self, aboveMaximum: String(UInt.max) + "0")
    }

    @Test func retriesExponentFromTheBeginningAfterOverflow() throws {
        // The significand overflows these destinations before the exponent makes it fit.
        let signed = Array("[1200e-1,-1200e-1,7]".utf8)
        #expect(try NewJSONDecoder().decode([Int8].self, from: signed.span.bytes) == [120, -120, 7])
        let unsigned = Array("[2500e-1,7]".utf8)
        #expect(try NewJSONDecoder().decode([UInt8].self, from: unsigned.span.bytes) == [250, 7])
    }

    @Test func rejectsUnrepresentableExponentResults() {
        for json in ["[1280e-1]", "[-1290e-1]", "[1201e-1]"] {
            let bytes = Array(json.utf8)
            #expect(throws: CodingError.Decoding.self) {
                try NewJSONDecoder().decode([Int8].self, from: bytes.span.bytes)
            }
        }
    }
}
