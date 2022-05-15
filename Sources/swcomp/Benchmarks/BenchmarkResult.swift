// Copyright (c) 2022 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct BenchmarkResult: Codable {
    var name: String
    var input: String
    var iterCount: Int
    var avg: Double
    var std: Double
}
