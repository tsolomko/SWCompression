//
//  Constants.swift
//  SWCompression
//
//  Created by Timofey Solomko on 19.08.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

struct Constants {

    /* Contents of test files:
     - test1: text file with "Hello, World!\n".
     - test2: text file with copyright free song lyrics from http://www.freesonglyrics.co.uk/lyrics13.html
     - test3: text file with random string from https://www.random.org/strings/
     - test4: text file with string "I'm a tester" repeated several times.
     - test5: empty file.
     - test6: file with size of 5MB containing nulls from /dev/null.
     - test7: file with size of 5MB containing random bytes from /dev/urandom.
     - test8: text file from lzma_specification.
     - test9: file with size of 10KB containing random bytes from /dev/urandom.
    */

    static func url(forTest name: String, withType ext: String) -> URL? {
        return testBundle.url(forResource: name, withExtension: ext)
    }

    static func url(forAnswer name: String) -> URL? {
        return testBundle.url(forResource: name, withExtension: "answer")
    }

    static let testBundle: Bundle = Bundle(for: DeflateTests.self)

}
