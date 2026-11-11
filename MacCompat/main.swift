
import Foundation

// ============================================================
// MACCOMPAT 1.0.0
// Main Core
// macOS Ventura / Intel compatible
// ============================================================

// MARK: - CONFIGURATION

enum MacCompat {
    static let version = "1.0.0"
    static let name = "MacCompat"
    static let supportedOS = "macOS"
}

// MARK: - CONSOLE

enum Console {

    static func banner() {
        print("""

        ================================================

          ███╗   ███╗ █████╗  ██████╗
          ████╗ ████║██╔══██╗██╔════╝
          ██╔████╔██║███████║██║
          ██║╚██╔╝██║██╔══██║██║
          ██║ ╚═╝ ██║██║  ██║╚██████╗
          ╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝

                     MACCOMPAT
                     VERSION \(MacCompat.version)

        ================================================

        """)
    }

    static func heading(_ title: String) {
        print("\n\(title)")
        print(String(repeating: "=", count: title.count))
    }

    static func success(_ message: String) {
        print("[PASS] \(message)")
    }

    static func warning(_ message: String) {
        print("[WARN] \(message)")
    }

    static func error(_ message: String) {
        print("[ERROR] \(message)")
    }
}

// MARK: - PROCESS EXECUTION

struct ProcessResult {
    let output: String
    let exitCode: Int32
    let succeeded: Bool
}

enum CommandRunner {

    static func execute(
        _ path: String,
        arguments: [String] = []
    ) -> ProcessResult {

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            process.waitUntilExit()

            let output = String(
                data: outputData,
                encoding: .utf8
            ) ?? ""

            let errorOutput = String(
                data: errorData,
                encoding: .utf8
            ) ?? ""

            return ProcessResult(
                output: output.isEmpty ? errorOutput : output,
                exitCode: process.terminationStatus,
                succeeded: process.terminationStatus == 0
            )

        } catch {
            return ProcessResult(
                output: error.localizedDescription,
                exitCode: -1,
                succeeded: false
            )
        }
    }

    static func text(
        _ path: String,
        arguments: [String] = []
    ) -> String {

        execute(path, arguments: arguments)
            .output
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - SYSTEM INFORMATION

struct SystemInformation {

    let macOSVersion: String
    let build: String
    let processor: String
    let logicalCores: String
    let memoryBytes: Int64

    static func collect() -> SystemInformation {

        let version = CommandRunner.text(
            "/usr/bin/sw_vers",
            arguments: ["-productVersion"]
        )

        let build = CommandRunner.text(
            "/usr/bin/sw_vers",
            arguments: ["-buildVersion"]
        )

        let processor = CommandRunner.text(
            "/usr/sbin/sysctl",
            arguments: ["-n", "machdep.cpu.brand_string"]
        )

        let cores = CommandRunner.text(
            "/usr/sbin/sysctl",
            arguments: ["-n", "hw.logicalcpu"]
        )

        let memory = CommandRunner.text(
            "/usr/sbin/sysctl",
            arguments: ["-n", "hw.memsize"]
        )

        return SystemInformation(
            macOSVersion: version,
            build: build,
            processor: processor,
            logicalCores: cores,
            memoryBytes: Int64(memory) ?? 0
        )
    }

    func display() {

        Console.heading("SYSTEM INFORMATION")

        print("macOS: \(macOSVersion)")
        print("Build: \(build)")
        print("Processor: \(processor)")
        print("Logical cores: \(logicalCores)")

        if memoryBytes > 0 {
            let gb = Double(memoryBytes) / 1_073_741_824
            print(String(format: "Memory: %.2f GB", gb))
        } else {
            print("Memory: UNKNOWN")
        }
    }
}

// MARK: - HARDWARE ANALYZER

enum HardwareAnalyzer {

    static func run() {

        Console.banner()
        Console.heading("HARDWARE ANALYZER")

        let system = SystemInformation.collect()
        system.display()

        Console.heading("STORAGE")

        let storage = CommandRunner.execute(
            "/bin/df",
            arguments: ["-h", "/"]
        )

        print(storage.output)

        Console.heading("GRAPHICS")

        let graphics = CommandRunner.execute(
            "/usr/sbin/system_profiler",
            arguments: ["SPDisplaysDataType"]
        )

        if graphics.succeeded {
            print(graphics.output)
        } else {
            Console.warning("Graphics information unavailable.")
        }
    }
}

// MARK: - APPLICATION INSPECTOR

struct ApplicationReport {

    let name: String
    let bundleID: String
    let version: String
    let build: String
    let minimumOS: String
    let category: String
    let executable: String
    let architecture: String
    let dependencies: String

    var text: String {
        """
        MACCOMPAT APPLICATION REPORT
        ============================

        Application: \(name)
        Bundle ID: \(bundleID)
        Version: \(version)
        Build: \(build)
        Minimum macOS: \(minimumOS)
        Category: \(category)
        Executable: \(executable)
        Architecture: \(architecture)

        DEPENDENCIES
        \(dependencies)

        """
    }
}

enum ApplicationInspector {

    static func inspect(_ path: String) -> ApplicationReport? {

        let url = URL(fileURLWithPath: path)

        guard let bundle = Bundle(url: url),
              let info = bundle.infoDictionary else {
            Console.error("Invalid application bundle.")
            return nil
        }

        guard let executableURL = bundle.executableURL else {
            Console.error("Application executable not found.")
            return nil
        }

        let executable = executableURL.path

        let architecture = CommandRunner.text(
            "/usr/bin/lipo",
            arguments: ["-info", executable]
        )

        let dependencies = CommandRunner.text(
            "/usr/bin/otool",
            arguments: ["-L", executable]
        )

        return ApplicationReport(
            name: info["CFBundleName"] as? String
                ?? url.deletingPathExtension().lastPathComponent,
            bundleID: info["CFBundleIdentifier"] as? String ?? "UNKNOWN",
            version: info["CFBundleShortVersionString"] as? String ?? "UNKNOWN",
            build: info["CFBundleVersion"] as? String ?? "UNKNOWN",
            minimumOS: info["LSMinimumSystemVersion"] as? String ?? "UNKNOWN",
            category: info["LSApplicationCategoryType"] as? String ?? "UNKNOWN",
            executable: executable,
            architecture: architecture,
            dependencies: dependencies
        )
    }

    static func export(
        _ report: ApplicationReport,
        destination: String
    ) {

        do {
            try report.text.write(
                toFile: destination,
                atomically: true,
                encoding: .utf8
            )

            Console.success("Report exported to \(destination)")

        } catch {
            Console.error(error.localizedDescription)
        }
    }
}

// MARK: - COMPATIBILITY ENGINE

enum CompatibilityEngine {

    static func evaluate(_ report: ApplicationReport) {

        Console.heading("COMPATIBILITY ENGINE")

        let currentOS = CommandRunner.text(
            "/usr/bin/sw_vers",
            arguments: ["-productVersion"]
        )

        let architectureSupported =
            report.architecture.contains("x86_64") ||
            report.architecture.contains("arm64")

        let osSupported = compareVersions(
            currentOS,
            report.minimumOS
        )

        print("Architecture: \(architectureSupported ? "SUPPORTED" : "UNKNOWN OR UNSUPPORTED")")
        print("Minimum macOS: \(osSupported ? "SUPPORTED" : "NOT CONFIRMED")")

        if architectureSupported && osSupported {
            Console.success("Compatibility checks passed.")
            print("RESULT: COMPATIBLE")
        } else {
            Console.warning("Compatibility could not be confirmed.")
            print("RESULT: REVIEW REQUIRED")
        }
    }

    private static func compareVersions(
        _ current: String,
        _ minimum: String
    ) -> Bool {

        if minimum == "UNKNOWN" || minimum.isEmpty {
            return false
        }

        let currentParts = current.split(separator: ".").compactMap {
            Int($0)
        }

        let minimumParts = minimum.split(separator: ".").compactMap {
            Int($0)
        }

        guard !currentParts.isEmpty,
              !minimumParts.isEmpty else {
            return false
        }

        let count = max(currentParts.count, minimumParts.count)

        let currentPadded = currentParts + Array(
            repeating: 0,
            count: count - currentParts.count
        )

        let minimumPadded = minimumParts + Array(
            repeating: 0,
            count: count - minimumParts.count
        )

        return !currentPadded.lexicographicallyPrecedes(minimumPadded)
    }
}

// MARK: - REPORT GENERATOR

enum ReportGenerator {

    static func generateSystemReport(destination: String) {

        let system = SystemInformation.collect()

        let report = """
        MACCOMPAT SYSTEM REPORT
        Version: \(MacCompat.version)

        macOS: \(system.macOSVersion)
        Build: \(system.build)
        Processor: \(system.processor)
        Logical cores: \(system.logicalCores)
        Memory: \(system.memoryBytes) bytes

        Storage:
        \(CommandRunner.text("/bin/df", arguments: ["-h", "/"]))

        Generated: \(Date())
        """

        do {
            try report.write(
                toFile: destination,
                atomically: true,
                encoding: .utf8
            )

            Console.success("System report generated.")

        } catch {
            Console.error(error.localizedDescription)
        }
    }
}

// MARK: - MACHAKINTEC MANAGER

enum MachakintecManager {

    static func run(_ action: String) {

        Console.heading("MACHAKINTEC MANAGER")

        switch action.lowercased() {

        case "init":
            print("Initialization structure ready.")

        case "status":
            print("Status: INITIALIZED")

        case "verify":
            print("Verification interface available.")
            print("No external payload is installed.")

        case "download":
            Console.warning("No verified official download source configured.")

        case "update":
            Console.warning("No verified official update source configured.")

        case "remove":
            print("No installed payload found.")

        default:
            Console.error("Unknown Machakintec command.")
        }
    }
}

// MARK: - COMMAND CENTER

enum CommandCenter {

    static func help() {

        print("""
        
        MACCOMPAT \(MacCompat.version)
        COMMAND REFERENCE
        =================

        --version
            Show version.

        --help
            Show help.

        hardware
            Inspect hardware.

        diagnostic
            Run Diagnostic Center.

        selftest
            Run automatic tests.

        analyze <app_path>
            Inspect an application.

        compatibility <app_path>
            Evaluate compatibility.

        compatibility <app_path> --export <file_path>
            Evaluate and export report.

        report <file_path>
            Generate system report.

        machakintec <command>
            Manage Machakintec.

        """)
    }

    static func execute(_ arguments: [String]) {

        guard let action = arguments.first?.lowercased() else {
            Console.banner()
            help()
            return
        }

        switch action {

        case "--version":
            print("MacCompat \(MacCompat.version)")

        case "--help":
            Console.banner()
            help()

        case "hardware":
            HardwareAnalyzer.run()

        case "diagnostic":
            DiagnosticCenter.run()

        case "selftest":
            SelfTest.run()

        case "analyze":

            guard arguments.count >= 2 else {
                Console.error("Application path required.")
                return
            }

            if let report = ApplicationInspector.inspect(arguments[1]) {
                print(report.text)
            }

        case "compatibility":

            guard arguments.count >= 2 else {
                Console.error("Application path required.")
                return
            }

            guard let report = ApplicationInspector.inspect(arguments[1]) else {
                return
            }

            CompatibilityEngine.evaluate(report)

            if arguments.count >= 4 &&
                arguments[2] == "--export" {

                ApplicationInspector.export(
                    report,
                    destination: arguments[3]
                )
            }

        case "report":

            guard arguments.count >= 2 else {
                Console.error("Destination path required.")
                return
            }

            ReportGenerator.generateSystemReport(
                destination: arguments[1]
            )

        case "machakintec":

            guard arguments.count >= 2 else {
                Console.error("Machakintec action required.")
                return
            }

            MachakintecManager.run(arguments[1])

        default:
            Console.error("Unknown command: \(action)")
            help()
        }
    }
}

// MARK: - ENTRY POINT

CommandCenter.execute(
    Array(CommandLine.arguments.dropFirst())
)

