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

    public init(lc: Int, lp: Int, pb: Int, dictionarySize: Int) {
        self.lc = lc
        self.lp = lp
        self.pb = pb
        self.dictionarySize = dictionarySize
    }

    init() {
        self.lc = 0
        self.lp = 0
        self.pb = 0
        self.dictionarySize = 0
    }

    init(lzmaByte: UInt8) throws {
        self.init()
        try self.updateProperties(lzmaByte: lzmaByte)
    }

    mutating func updateProperties(lzmaByte: UInt8) throws {
        guard lzmaByte < 9 * 5 * 5
            else { throw LZMAError.wrongProperties }

        let intByte = lzmaByte.toInt()

        self.lc = intByte % 9
        self.pb = (intByte / 9) / 5
        self.lp = (intByte / 9) % 5
    }

}
