// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct Constants {

    /* Contents of test files:
     - test1: text file with "Hello, World!\n".
     - test2: text file with copyright free song lyrics from http://www.freesonglyrics.co.uk/lyrics13.html
     - test3: text file with random string from https://www.random.org/strings/
     - test4: text file with string "I'm a tester" repeated several times.
     - test6: file with size of 5MB containing nulls from /dev/null.
     - test7: file with size of 5MB containing random bytes from /dev/urandom.
     - test8: text file from lzma_specification.
     - test9: file with size of 10KB containing random bytes from /dev/urandom.
    */

    static func data(forTest name: String, withType ext: String) -> Data? {
        if let url = Constants.url(forTest: name, withType: ext) {
            return try? Data(contentsOf: url, options: .mappedIfSafe)
        } else {
            return nil
        }
    }

    private static func url(forTest name: String, withType ext: String) -> URL? {
        return testBundle.url(forResource: name, withExtension: ext)
    }

    static func data(forAnswer name: String) -> Data? {
        if let url = Constants.url(forAnswer: name) {
            return try? Data(contentsOf: url, options: .mappedIfSafe)
        } else {
            return nil
        }
    }

    private static func url(forAnswer name: String) -> URL? {
        return testBundle.url(forResource: name, withExtension: "answer")
    }

    private static let testBundle: Bundle = Bundle(for: DeflateTests.self)

}
