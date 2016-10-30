//
//  Constants.swift
//  SWCompression
//
//  Created by Timofey Solomko on 19.08.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

struct Constants {

    static let testBundle = Bundle(for: SWCompressionTests.self)

    static let helloWorldArchivePath = testBundle.url(forResource: "helloworld.txt",
                                                      withExtension: "gz")!

    static let secondTestArchivePath = testBundle.url(forResource: "secondtest.txt",
                                                      withExtension: "gz")!
    static let secondTestAnswerPath = testBundle.url(forResource: "secondtest",
                                                     withExtension: "txt")!

    static let emptyFileArchivePath = testBundle.url(forResource: "empty.txt",
                                                     withExtension: "gz")!

    static let helloWorldZlibPath = testBundle.url(forResource: "helloworld.txt",
                                                      withExtension: "zlib")!

}
