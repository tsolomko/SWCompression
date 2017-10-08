// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

extension Int {

    func octalToDecimal() -> Int {
        var octal = self
        var decimal = 0, i = 0
        while octal != 0 {
            let remainder = octal % 10
            octal /= 10
            decimal += remainder * Int(pow(8, Double(i)))
            i += 1
        }
        return decimal
    }

    func roundTo512() -> Int {
        let fractionNum = Double(self) / 512
        let roundedNum = Int(ceil(fractionNum))
        return roundedNum * 512
    }

}
