// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

extension LZ4: CompressionAlgorithm {

    public static func compress(data: Data) throws -> Data {
        fatalError("Not implemented yet.")
    }

    private static func compress(data: Data, independentBlocks: Bool, blockChecksums: Bool,
                                 contentChecksum: Bool, contentSize: Bool) throws -> Data {
        fatalError("Not implemented yet.")
    }

}
