//
//  Constants.swift
//  SWCompression
//
//  Created by Timofey Solomko on 19.08.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

struct Constants {

    static func url(forTest name: String, withType ext: String) -> URL {
        return testBundle.url(forResource: name, withExtension: ext)!
    }

    static func url(forAnswer name: String) -> URL {
        return testBundle.url(forResource: name, withExtension: "answer")!
    }

    static let testBundle = Bundle(for: ZlibTests.self)

    static let relativelyBigFilePath = testBundle.url(forResource: "performance_test1",
                                                        withExtension: "gz")!

}
