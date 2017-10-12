// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public protocol ContainerEntryInfo {

    var name: String? { get }

    var type: ContainerEntryType { get }

    var size: Int? { get }

    // TODO: a/c/m times.
    // TODO: uncompressed and compressed sizes?

}
