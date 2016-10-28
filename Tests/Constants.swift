//
//  Constants.swift
//  SWCompression
//
//  Created by Timofey Solomko on 19.08.16.
//  Copyright © 2016 tsolomko. All rights reserved.
//

import Foundation

struct Constants {
    static let testBundle = Bundle(for: SWCompressionTests.self)
    static let helloWorldArchivePath = testBundle.url(forResource: "helloworld.txt", withExtension: "gz")!
    static let secondTestArchivePath = testBundle.url(forResource: "secondtest.txt", withExtension: "gz")!
}
