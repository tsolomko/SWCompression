// Copyright (c) 2022 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct SaveFile: Codable {

    var timestamp: TimeInterval
    var osInfo: String
    var swiftVersion: String
    var swcVersion: String
    var description: String?
    var results: [BenchmarkResult]

    var groupedResults: [String: [BenchmarkResult]] {
        return Dictionary(grouping: self.results, by: { $0.id })
    }

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
        #if os(Windows)
            swcompExit(.benchmarkCannotGetSubcommandPathWindows)
        #else
            let output = try SaveFile.run(command: URL(fileURLWithPath: "/bin/sh"), arguments: args)
        #endif
        return URL(fileURLWithPath: String(output.dropLast()))
    }

    private static func getOsInfo() throws -> String {
        #if os(Linux)
            return try SaveFile.run(command: SaveFile.getExecURL(for: "uname"), arguments: ["-a"])
        #else
            #if os(Windows)
                return "Unknown Windows OS"
            #else
                return try SaveFile.run(command: SaveFile.getExecURL(for: "sw_vers"))
            #endif
        #endif
    }

    init(_ description: String?, _ results: [BenchmarkResult]) throws {
        self.timestamp = Date.timeIntervalSinceReferenceDate
        self.osInfo = try SaveFile.getOsInfo()
        #if os(Windows)
            self.swiftVersion = "Unknown Swift version on Windows"
        #else
            self.swiftVersion = try SaveFile.run(command: SaveFile.getExecURL(for: "swift"), arguments: ["-version"])
        #endif
        self.swcVersion = _SWC_VERSION
        self.description = description
        self.results = results
    }

    func printMetadata() {
        print("OS Info: \(self.osInfo)", terminator: "")
        print("Swift version: \(self.swiftVersion)", terminator: "")
        print("SWC version: \(self.swcVersion)")
        print("Timestamp: " +
            DateFormatter.localizedString(from: Date(timeIntervalSinceReferenceDate: self.timestamp),
                                          dateStyle: .short, timeStyle: .short))
        if let description = self.description {
            print("Description: \(description)")
        }
        print()
    }

    static func load(from path: String) throws -> SaveFile {
        let decoder = JSONDecoder()
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try decoder.decode(SaveFile.self, from: data)
    }

}
