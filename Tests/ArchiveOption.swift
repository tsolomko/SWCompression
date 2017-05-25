//
//  ArchiveOptions.swift
//  SWCompression
//
//  Created by Timofey Solomko on 24.05.17.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

public enum ArchiveOption {
    case mtime(Date)
    case fileName(String)
    case comment(String)
    case isTextFile
    case gzipOS(Int)
    case gzipHeaderCRC
}
