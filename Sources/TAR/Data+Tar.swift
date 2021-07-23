// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

extension Data {

    @inline(__always)
    mutating func appendAsTarBlock(_ data: Data) {
        self.append(data)
        let paddingSize = data.count.roundTo512() - data.count
        self.append(Data(count: paddingSize))
    }

}
