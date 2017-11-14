// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// A type that represents a container with files, directories and/or other data.
public protocol Container {

    associatedtype Entry: ContainerEntry

    /// Retrieve all the entries with their data from the container.
    static func open(container: Data) throws -> [Entry]

    /// Retrieve information abouth all the entries from the container (without their data).
    static func info(container: Data) throws -> [Entry.Info]

}
