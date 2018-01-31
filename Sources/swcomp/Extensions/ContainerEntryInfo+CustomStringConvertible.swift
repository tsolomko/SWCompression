// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression

extension ContainerEntryInfo where Self: CustomStringConvertible {

    public var description: String {
        var output = ""
        output += "Name: \(self.name)\n"

        switch self.type {
        case .blockSpecial:
            output += "Type: block device file\n"
        case .characterSpecial:
            output += "Type: character device file\n"
        case .contiguous:
            output += "Type: contiguous file\n"
        case .directory:
            output += "Type: directory\n"
        case .fifo:
            output += "Type: fifo file\n"
        case .hardLink:
            output += "Type: hard link\n"
        case .regular:
            output += "Type: regular file\n"
        case .socket:
            output += "Type: socket\n"
        case .symbolicLink:
            output += "Type: symbolic link\n"
        case .unknown:
            output += "Type: unknown\n"
        }

        if let tarEntry = self as? TarEntryInfo {
            if tarEntry.type == .symbolicLink {
                output += "Linked path: \(tarEntry.linkName)\n"
            }
        }

        if let size = self.size {
            output += "Size: \(size) bytes\n"
        }

        if let mtime = self.modificationTime {
            output += "Mtime: \(mtime)\n"
        }

        if let atime = self.accessTime {
            output += "Atime: \(atime)\n"
        }

        if let ctime = self.creationTime {
            output += "Ctime: \(ctime)\n"
        }

        if let permissions = self.permissions?.rawValue {
            output += String(format: "Permissions: %o", permissions)
        }

        return output
    }

}

extension TarEntryInfo: CustomStringConvertible { }

extension ZipEntryInfo: CustomStringConvertible { }

extension SevenZipEntryInfo: CustomStringConvertible { }
