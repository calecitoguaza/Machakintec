
import Foundation

struct DiagnosticCenter {

    static func run() {
        print("""
        
        ========================================
              MACCOMPAT DIAGNOSTIC CENTER
                     VERSION 0.9.0
        ========================================
        
        """)

        section(1, "OPERATING SYSTEM")
        print("macOS: \(runCommand("/usr/bin/sw_vers", arguments: ["-productVersion"]))")
        print("Build: \(runCommand("/usr/bin/sw_vers", arguments: ["-buildVersion"]))")
        print("Status: AVAILABLE")

        section(2, "PROCESSOR")
        print("Model: \(runCommand("/usr/sbin/sysctl", arguments: ["-n", "machdep.cpu.brand_string"]))")
        print("Logical cores: \(runCommand("/usr/sbin/sysctl", arguments: ["-n", "hw.logicalcpu"]))")
        print("Status: AVAILABLE")

        section(3, "MEMORY")
        let memory = runCommand("/usr/sbin/sysctl", arguments: ["-n", "hw.memsize"])
        if let bytes = Double(memory) {
            print(String(format: "Installed RAM: %.2f GB", bytes / 1_073_741_824))
        } else {
            print("Installed RAM: UNKNOWN")
        }
        print("Status: AVAILABLE")

        section(4, "STORAGE")
        let storage = runCommand("/bin/df", arguments: ["-h", "/"])
        let lines = storage.components(separatedBy: "\n")
        if lines.count > 1 {
            let columns = lines[1].split(whereSeparator: { $0.isWhitespace })
            if columns.count > 3 {
                print("Available space: \(columns[3])")
            } else {
                print("Available space: UNKNOWN")
            }
        } else {
            print("Available space: UNKNOWN")
        }
        print("Status: AVAILABLE")

        section(5, "SYSTEM TOOLS")
        checkTool("sw_vers", path: "/usr/bin/sw_vers")
        checkTool("sysctl", path: "/usr/sbin/sysctl")
        checkTool("df", path: "/bin/df")
        checkTool("otool", path: "/usr/bin/otool")
        checkTool("lipo", path: "/usr/bin/lipo")

        print("""

        ========================================
                 DIAGNOSTIC COMPLETED
        ========================================

        """)
    }

    private static func section(_ number: Int, _ name: String) {
        print("\n[\(number)] \(name)\n")
    }

    private static func checkTool(_ name: String, path: String) {
        let exists = FileManager.default.isExecutableFile(atPath: path)
        print("\(name): \(exists ? "AVAILABLE" : "MISSING")")
    }

    private static func runCommand(_ path: String, arguments: [String]) -> String {
        let process = Process()
        let output = Pipe()

        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "UNKNOWN"
        } catch {
            return "UNKNOWN"
        }
    }
}

