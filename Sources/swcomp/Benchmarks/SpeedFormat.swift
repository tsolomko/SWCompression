// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

enum SpeedFormat {

    case bytes(Double)
    case kilo(Double)
    case mega(Double)
    case giga(Double)
    case tera(Double)

    init(_ speed: Double) {
        if speed > pow(1000, 4) {
            self = .tera(speed)
        } else if speed > pow(1000, 3) {
            self = .giga(speed)
        } else if speed > pow(1000, 2) {
            self = .mega(speed)
        } else if speed > 1000 {
            self = .kilo(speed)
        } else {
            self = .bytes(speed)
        }
    }

    func format() -> String {
        switch self {
        case .bytes(let speed):
            return String(format: "%.3f B/s", speed)
        case .kilo(let speed):
            return String(format: "%.3f kB/s", speed / 1000)
        case .mega(let speed):
            return String(format: "%.3f MB/s", speed / 1000 / 1000)
        case .giga(let speed):
            return String(format: "%.3f GB/s", speed / 1000 / 1000 / 1000)
        case .tera(let speed):
            return String(format: "%.3f TB/s", speed / 1000 / 1000 / 1000 / 1000)
        }
    }

    func format(_ speed: Double) -> String {
        switch self {
        case .bytes(_):
            return String(format: "%.3f B/s", speed)
        case .kilo(_):
            return String(format: "%.3f kB/s", speed / 1000)
        case .mega(_):
            return String(format: "%.3f MB/s", speed / 1000 / 1000)
        case .giga(_):
            return String(format: "%.3f GB/s", speed / 1000 / 1000 / 1000)
        case .tera(_):
            return String(format: "%.3f TB/s", speed / 1000 / 1000 / 1000 / 1000)
        }
    }

}
