// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

protocol Benchmark {

    var defaultIterationCount: Int { get }

    init(_ input: String)

    func warmupIteration() -> Double

    func measure() -> Double

    func format(_ value: Double) -> String

}

extension Benchmark {

    var defaultIterationCount: Int {
        return 10
    }

    func warmupIteration() -> Double {
        return measure()
    }

    func format(_ value: Double) -> String {
        return SpeedFormatter.default.string(from: value)
    }

}
