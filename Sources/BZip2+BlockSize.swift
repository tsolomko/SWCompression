// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public extension BZip2 {

    public enum BlockSize: Int {
        case one = 1
        case two = 2
        case three = 3
        case four = 4
        case five = 5
        case six = 6
        case seven = 7
        case eight = 8
        case nine = 9
    }
}

extension BZip2.BlockSize {

    func headerByte() -> Int {
        switch self {
        case .one:
            return 0x31
        case .two:
            return 0x32
        case .three:
            return 0x33
        case .four:
            return 0x34
        case .five:
            return 0x35
        case .six:
            return 0x36
        case .seven:
            return 0x37
        case .eight:
            return 0x38
        case .nine:
            return 0x39
        }
    }

}
