import Foundation

public struct ProcessResult: Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public var isSuccess: Bool {
        exitCode == 0
    }

    public var combinedOutput: String {
        if stdout.isEmpty { return stderr }
        if stderr.isEmpty { return stdout }
        return stdout + "\n" + stderr
    }
}

public actor ProcessRunner {
    public static let shared = ProcessRunner()

    public init() {}

    /// Run a command and wait for its full output
    public func run(
        executable: String,
        arguments: [String],
        environment: [String: String]? = nil,
        currentDirectory: URL? = nil
    ) async throws -> ProcessResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        if let currentDirectory = currentDirectory {
            process.currentDirectoryURL = currentDirectory
        }

        var env = ProcessInfo.processInfo.environment
        if let environment = environment {
            for (key, val) in environment {
                env[key] = val
            }
        }
        // Ensure standard PATH has Homebrew and Android SDK paths
        let standardPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        if let existingPath = env["PATH"] {
            env["PATH"] = "\(standardPaths):\(existingPath)"
        } else {
            env["PATH"] = standardPaths
        }
        process.environment = env

        return try await withCheckedThrowingContinuation { continuation in
            do {
                process.terminationHandler = { proc in
                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                    let result = ProcessResult(
                        exitCode: proc.terminationStatus,
                        stdout: stdout,
                        stderr: stderr
                    )
                    continuation.resume(returning: result)
                }

                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Stream output lines in real-time as the process runs
    public func stream(
        executable: String,
        arguments: [String],
        currentDirectory: URL? = nil,
        onOutput: @escaping @Sendable (String, Bool) -> Void // (line, isError)
    ) async throws -> Int32 {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        if let currentDirectory = currentDirectory {
            process.currentDirectoryURL = currentDirectory
        }

        var env = ProcessInfo.processInfo.environment
        let standardPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        if let existingPath = env["PATH"] {
            env["PATH"] = "\(standardPaths):\(existingPath)"
        } else {
            env["PATH"] = standardPaths
        }
        process.environment = env

        // Read stdout asynchronously
        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading

        stdoutHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            for line in text.components(separatedBy: .newlines) where !line.isEmpty {
                onOutput(line, false)
            }
        }

        stderrHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            for line in text.components(separatedBy: .newlines) where !line.isEmpty {
                onOutput(line, true)
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                stdoutHandle.readabilityHandler = nil
                stderrHandle.readabilityHandler = nil
                continuation.resume(returning: proc.terminationStatus)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
