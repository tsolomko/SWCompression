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

    func compare(with other: BenchmarkResult) -> Int? {
        let degreesOfFreedom = Double(self.iterCount + other.iterCount - 2)
        let t1: Double = Double(self.iterCount - 1) * pow(self.std, 2)
        let t2: Double = Double(other.iterCount - 1) * pow(other.std, 2)
        let pooledStd = ((t1 + t2) / degreesOfFreedom).squareRoot()
        let se = pooledStd * (1 / Double(self.iterCount) + 1 / Double(other.iterCount)).squareRoot()
        let tStat = (self.avg - other.avg ) / se
        if degreesOfFreedom == 18 {
            if abs(tStat) > 2.101 {
                // p-value < 0.05
                return -1
            } else if abs(tStat) == 2.101 {
                // p-value = 0.05
                return 0
            } else {
                // p-value > 0.05
                return 1
            }
        } else {
            return nil
        }
    }

}
