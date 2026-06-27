// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct BenchmarkMetadata: Codable, Equatable {

    var timestamp: TimeInterval?
    var osInfo: String
    var swiftVersion: String
    var swcVersion: String
    var description: String?

    private static func run(command: URL, arguments: [String] = []) throws -> String {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.executableURL = command
        task.arguments = arguments
        task.standardInput = nil

        try task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        return output
    }

    private static func getExecURL(for command: String) throws -> URL {
        let args = ["-c", "which \(command)"]
        let output = try BenchmarkMetadata.run(command: URL(fileURLWithPath: "/bin/sh"), arguments: args)
        return URL(fileURLWithPath: String(output.dropLast()))
    }

    private static func getOsInfo() throws -> String {
        return try BenchmarkMetadata.run(command: BenchmarkMetadata.getExecURL(for: "sw_vers"))
    }

    init(_ description: String?, _ preserveTimestamp: Bool) throws {
        self.timestamp = preserveTimestamp ? Date.timeIntervalSinceReferenceDate : nil
        self.osInfo = try BenchmarkMetadata.getOsInfo()
        self.swiftVersion = try BenchmarkMetadata.run(command: BenchmarkMetadata.getExecURL(for: "swift"),
                                                        arguments: ["-version"])
        self.swcVersion = _SWC_VERSION
        self.description = description
    }

    func print() {
        Swift.print("OS Info: \(self.osInfo)", terminator: "")
        Swift.print("Swift version: \(self.swiftVersion)", terminator: "")
        Swift.print("SWC version: \(self.swcVersion)")
        if let timestamp = self.timestamp {
            Swift.print("Timestamp: " +
                DateFormatter.localizedString(from: Date(timeIntervalSinceReferenceDate: timestamp),
                                            dateStyle: .short, timeStyle: .short))
        }
        if let description = self.description {
            Swift.print("Description: \(description)")
        }
        Swift.print()
    }

}
