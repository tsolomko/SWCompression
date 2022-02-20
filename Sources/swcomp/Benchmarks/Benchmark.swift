// Copyright (c) 2022 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

protocol Benchmark {

    static var defaultIterationCount: Int { get }

    init(_ input: String)

    func warmupIteration()

    func measure() -> Double

}

extension Benchmark {

    static var defaultIterationCount: Int {
        return 10
    }

    func warmupIteration() {
        _ = measure()
    }

}
