// Copyright (c) 2022 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

protocol Benchmark {

    init(_ input: String)

    func warmupIteration()

    func measure() -> Double

}

extension Benchmark {

    func warmupIteration() {
        _ = measure()
    }

}
