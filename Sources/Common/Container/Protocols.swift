// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public protocol Container {

    associatedtype Entry: ContainerEntry

    static func open(container: Data) throws -> [Entry]

    static func info(container: Data) throws -> [Entry.Info]

}

public protocol ContainerEntry {

    associatedtype Info: ContainerEntryInfo

    var info: Info { get }

    var data: Data? { get }

}

public protocol ContainerEntryInfo {

    var name: String? { get }

    var type: ContainerEntryType? { get }

    var size: Int? { get }

    // TODO: a/c/m times.
    // TODO: uncompressed and compressed sizes?

}

public enum ContainerEntryType {

}
