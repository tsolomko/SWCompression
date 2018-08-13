// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

public struct LZMAProperties {

    public var lc: Int
    public var lp: Int
    public var pb: Int
    public var dictionarySize: Int {
        didSet {
            if dictionarySize < 1 << 12 {
                dictionarySize = 1 << 12
            }
        }
    }

}
