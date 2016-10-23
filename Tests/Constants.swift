//
//  Constants.swift
//  SWCompression
//
//  Created by Timofey Solomko on 19.08.16.
//  Copyright © 2016 tsolomko. All rights reserved.
//

import Foundation

struct Constants {
    fileprivate static let testBundle = Bundle(for: SWCompressionTests.self)
    static let testArchivePath = testBundle.url(forResource: "test.txt", withExtension: "gz")!
}
