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
