#!/usr/bin/env swift
import Foundation

struct Case: Decodable { let id: String; let language: String; let text: String; let criticalTerms: [String] }

@discardableResult
func run(_ executable: String, _ arguments: [String]) throws -> String {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = output
    process.standardError = output
    try process.run()
    process.waitUntilExit()
    let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    guard process.terminationStatus == 0 else {
        throw NSError(domain: "benchmark", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: text])
    }
    return text
}

func words(_ text: String) -> [String] {
    text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_BR"))
        .lowercased()
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }
}

func distance(_ lhs: [String], _ rhs: [String]) -> Int {
    var row = Array(0...rhs.count)
    for (i, left) in lhs.enumerated() {
        var next = [i + 1] + Array(repeating: 0, count: rhs.count)
        for (j, right) in rhs.enumerated() {
            next[j + 1] = min(next[j] + 1, row[j + 1] + 1, row[j] + (left == right ? 0 : 1))
        }
        row = next
    }
    return row[rhs.count]
}

guard (3...4).contains(CommandLine.arguments.count) else {
    fputs("uso: Scripts/benchmark-output.swift <modelo.bin> <diretorio-saida> [prompt]\n", stderr)
    exit(64)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let corpus = try JSONDecoder().decode([Case].self, from: Data(contentsOf: root.appendingPathComponent("Tests/Fixtures/output-corpus.json")))
let model = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let prompt = CommandLine.arguments.count == 4 ? CommandLine.arguments[3] : ""
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

var totalEdits = 0
var totalWords = 0
var criticalHits = 0
var criticalCount = 0
var durations: [Double] = []

for item in corpus {
    let aiff = output.appendingPathComponent("\(item.id).aiff")
    let wav = output.appendingPathComponent("\(item.id).wav")
    let prefix = output.appendingPathComponent("\(item.id)-transcript")
    if !FileManager.default.fileExists(atPath: wav.path) {
        try run("/usr/bin/say", ["-v", "Luciana", "-o", aiff.path, item.text])
        try run("/opt/homebrew/bin/ffmpeg", ["-loglevel", "error", "-y", "-i", aiff.path, "-ar", "16000", "-ac", "1", wav.path])
    }
    let started = Date()
    var arguments = ["-m", model.path, "-f", wav.path, "-l", item.language, "-otxt", "-of", prefix.path, "-np", "-nt"]
    if !prompt.isEmpty { arguments += ["--prompt", prompt] }
    try run("/opt/homebrew/bin/whisper-cli", arguments)
    durations.append(Date().timeIntervalSince(started))
    let actual = try String(contentsOf: prefix.appendingPathExtension("txt"), encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let expectedWords = words(item.text)
    totalEdits += distance(expectedWords, words(actual))
    totalWords += expectedWords.count
    var missingTerms: [String] = []
    for term in item.criticalTerms {
        criticalCount += 1
        if actual.range(of: term) != nil { criticalHits += 1 } else { missingTerms.append(term) }
    }
    print("\(item.id) | \(String(format: "%.2fs", durations.last!)) | \(actual)")
    if !missingTerms.isEmpty { print("  missing exact: \(missingTerms.joined(separator: ", "))") }
}

let sorted = durations.sorted()
let p50 = sorted[sorted.count / 2]
let p95 = sorted[min(sorted.count - 1, Int(ceil(Double(sorted.count) * 0.95)) - 1)]
print(String(format: "RESULT model=%@ WER=%.3f critical=%d/%d P50=%.2fs P95=%.2fs", model.lastPathComponent,
    Double(totalEdits) / Double(max(totalWords, 1)), criticalHits, criticalCount, p50, p95))
