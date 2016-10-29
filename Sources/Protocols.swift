//
//  Protocols.swift
//  SWCompression
//
//  Created by Timofey Solomko on 29.10.16.
//  Copyright © 2016 tsolomko. All rights reserved.
//

import Foundation

public protocol Archive {

    static func unarchive(archiveData: Data) throws -> Data

}

public protocol DecompressionAlgorithm {

    static func decompress(compressedData: Data) throws -> Data

}
