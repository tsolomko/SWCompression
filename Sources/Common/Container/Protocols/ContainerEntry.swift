// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public protocol ContainerEntry {

    associatedtype Info: ContainerEntryInfo

    var info: Info { get }

    var data: Data? { get }

}
