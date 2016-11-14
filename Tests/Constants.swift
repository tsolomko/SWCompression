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

    static let helloWorldArchivePath = testBundle.url(forResource: "test1",
                                                      withExtension: "gz")!

    static let secondTestArchivePath = testBundle.url(forResource: "test4",
                                                      withExtension: "gz")!
    static let secondTestAnswerPath = testBundle.url(forResource: "test4",
                                                     withExtension: "answer")!

    static let emptyFileArchivePath = testBundle.url(forResource: "test5",
                                                     withExtension: "gz")!

    static let helloWorldZlibPath = testBundle.url(forResource: "test1",
                                                      withExtension: "zlib")!

    static let secondZlibTestPath = testBundle.url(forResource: "test2",
                                                   withExtension: "zlib")!
    static let secondZlibTestAnswerPath = testBundle.url(forResource: "test2",
                                                         withExtension: "answer")!

    static let thirdZlibTestPath = testBundle.url(forResource: "test3",
                                                   withExtension: "zlib")!
    static let thirdZlibTestAnswerPath = testBundle.url(forResource: "test3",
                                                         withExtension: "answer")!


    static let relativelyBigFilePath = testBundle.url(forResource: "performance_test1",
                                                        withExtension: "gz")!

}
