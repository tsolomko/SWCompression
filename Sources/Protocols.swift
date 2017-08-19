// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// A type that represents an archive.
public protocol Archive {

    /// Unarchive data from the archive.
    static func unarchive(archive: Data) throws -> Data

}

/// A type that provides an implementation of a particular decompression algorithm.
public protocol DecompressionAlgorithm {

    /// Decompress data compressed with particular algorithm.
    static func decompress(data: Data) throws -> Data

}

/// A type that represents a container of files, directories and/or other data.
public protocol Container {

    /// Retrieve all the entries from the container.
    static func open(container: Data) throws -> [ContainerEntry]

}

/// A type that represents an entry from a container (file or directory) with attributes.
public protocol ContainerEntry {

    /// Retrieve name of the entry from the container.
    var name: String { get }

    /// Retrieve size of the entry's data from the container.
    var size: Int { get }

    /// True, if entry is a directory.
    var isDirectory: Bool { get }

    /// True, if entry is a symbolic link.
    var isLink: Bool { get }

    /// Path to a linked file for symbolic link entry.
    var linkPath: String? { get }

    /**
     Provides a dictionary with various attributes of the entry.
     `FileAttributeKey` values are used as dictionary keys.

     - Note:
     Will be renamed to `attributes` in 4.0.
     */
    var entryAttributes: [FileAttributeKey: Any] { get }

    /// Retrieve entry's data from the container.
    func data() throws -> Data

}
