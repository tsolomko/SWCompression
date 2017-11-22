// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

extension Data {

    @inline(__always)
    func to<T>(type: T.Type) -> T {
        return self.withUnsafeBytes { $0.pointee }
    }

    @inline(__always)
    func toArray<T>(type: T.Type, count: Int) -> [T] {
        return self.withUnsafeBytes {
            [T](UnsafeBufferPointer(start: $0, count: count))
        }
    }

    @inline(__always)
    func toArray<T>(type: T.Type) -> [T] {
        return self.toArray(type: type, count: self.count / MemoryLayout<T>.size)
    }

}

extension UnsignedInteger {

    @inline(__always)
    func toInt() -> Int {
        return Int(truncatingIfNeeded: self)
    }
}

extension Int {

    @inline(__always)
    func toUInt8() -> UInt8 {
        return UInt8(truncatingIfNeeded: UInt(self))
    }

}

extension Date {

    init?(_ ntfsTime: UInt64?) {
        if let time = ntfsTime,
            let ntfsStartDate = DateComponents(calendar: Calendar(identifier: .iso8601),
                                               timeZone: TimeZone(abbreviation: "UTC"),
                                               year: 1601, month: 1, day: 1,
                                               hour: 0, minute: 0, second: 0).date {
            self.init(timeInterval: TimeInterval(time) / 10_000_000, since: ntfsStartDate)
        } else {
            return nil
        }
    }

}
