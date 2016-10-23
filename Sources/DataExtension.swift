//
//  DataExtension.swift
//  SWCompression
//
//  Created by Timofey Solomko on 19.09.16.
//  Copyright © 2016 tsolomko. All rights reserved.
//

import Foundation

extension Data {

    func to<T>(type: T.Type) -> T {
        return self.withUnsafeBytes { $0.pointee }
    }

    func toArray<T>(type: T.Type) -> [T] {
        return self.withUnsafeBytes {
            [T](UnsafeBufferPointer(start: $0, count: self.count/MemoryLayout<T>.size))
        }
    }

    subscript(range: Range<Data.Index>) -> Data {
        return self.subdata(in: range)
    }

    subscript(index: Data.Index) -> Data {
        return self.subdata(in: index..<index+1)
    }

    func bytes(from range: Range<Data.Index>) -> [UInt8] {
        return self.subdata(in: range).toArray(type: UInt8.self)
    }

    func byte(at index: Data.Index) -> UInt8 {
        return Data(self[index]).to(type: UInt8.self)
    }
    
}
