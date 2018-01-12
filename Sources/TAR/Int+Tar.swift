// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

extension Int {

    func roundTo512() -> Int {
        let fractionNum = Double(self) / 512
        let roundedNum = Int(ceil(fractionNum))
        return roundedNum * 512
    }

}
