// Copyright (c) 2022 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

protocol Benchmark {

    var defaultIterationCount: Int { get }
    static var useSpeedFormatter: Bool { get }

    init(_ input: String)

    func warmupIteration()

    func measure() -> Double

}

extension Benchmark {

    static var useSpeedFormatter: Bool {
        return true
    }

    var defaultIterationCount: Int {
        return 10
    }

    func warmupIteration() {
        _ = measure()
    }

}
