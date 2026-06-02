// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

class Constants {

    /* Contents of test files:
     - test1: text file with "Hello, World!\n".
     - test2: text file with copyright free song lyrics from http://www.freesonglyrics.co.uk/lyrics13.html
     - test3: text file with random string from https://www.random.org/strings/
     - test4: text file with string "I'm a tester" repeated several times.
     - test5: empty file.
     - test6: file with size of 1MB containing nulls from /dev/zero.
     - test7: file with size of 1MB containing random bytes from /dev/urandom.
     - test8: text file from lzma_specification.
     - test9: file with size of 10KB containing random bytes from /dev/urandom.
    */

    static func data(forTest name: String, withType ext: String) throws -> Data {
        let url = Constants.url(forTest: name, withType: ext)
        return try Data(contentsOf: url)
    }

    static func handle(forTest name: String, withType ext: String) throws -> FileHandle {
        let url = Constants.url(forTest: name, withType: ext)
        return try FileHandle(forReadingFrom: url)
    }

    private static func url(forTest name: String, withType ext: String) -> URL {
        return testBundle.url(forResource: name, withExtension: ext)!
    }

    static func data(forAnswer name: String) throws -> Data {
        let url = Constants.url(forAnswer: name)
        return try Data(contentsOf: url)
    }

    private static func url(forAnswer name: String) -> URL {
        return testBundle.url(forResource: name, withExtension: "answer")!
    }

    static let текстовыйФайлData = Data([208, 154, 208, 176, 208, 186, 208, 190, 208, 185, 45, 209, 130, 208, 190, 32,
                                         209, 130, 208, 181, 208, 186, 209, 129, 209, 130, 46, 32, 208, 148, 208, 176,
                                         208, 178, 208, 176, 208, 185, 209, 130, 208, 181, 32, 208, 191, 209, 128, 208,
                                         190, 208, 178, 208, 181, 209, 128, 208, 184, 208, 188, 44, 32, 208, 186, 208,
                                         176, 208, 186, 32, 209, 132, 208, 176, 208, 185, 208, 187, 32, 209, 129, 32,
                                         208, 189, 208, 176, 208, 183, 208, 178, 208, 176, 208, 189, 208, 184, 208, 181,
                                         208, 188, 44, 32, 208, 184, 209, 129, 208, 191, 208, 190, 208, 187, 209, 140,
                                         208, 183, 209, 131, 209, 142, 209, 137, 208, 181, 208, 188, 32, 208, 174, 208,
                                         189, 208, 184, 208, 186, 208, 190, 208, 180, 44, 32, 209, 129, 208, 190, 209,
                                         133, 209, 128, 208, 176, 208, 189, 208, 184, 209, 130, 209, 129, 209, 143, 32,
                                         208, 178, 32, 208, 151, 208, 152, 208, 159, 45, 208, 186, 208, 190, 208, 189,
                                         209, 130, 208, 181, 208, 185, 208, 189, 208, 181, 209, 128, 208, 181, 46, 10])

    #if SWIFT_PACKAGE
        private static let testBundle: Bundle = Bundle.module
    #else
        private static let testBundle: Bundle = Bundle(for: Constants.self)
    #endif

}
