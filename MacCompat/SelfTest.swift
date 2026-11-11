

import Foundation

struct SelfTest {

    static func run() {
        print("""
        
        ========================================
                 MACCOMPAT SELF TEST
                     VERSION 0.9.5
        ========================================
        
        """)

        var passed = 0
        var failed = 0

        func check(_ name: String, _ condition: Bool) {
            if condition {
                print("[PASS] \(name)")
                passed += 1
            } else {
                print("[FAIL] \(name)")
                failed += 1
            }
        }

        // 1. Operating System
        let macOS = execute("/usr/bin/sw_vers", ["-productVersion"])
        check("macOS detection", !macOS.isEmpty)

        // 2. Processor
        let processor = execute(
            "/usr/sbin/sysctl",
            ["-n", "machdep.cpu.brand_string"]
        )
        check("Processor detection", !processor.isEmpty)

        // 3. Logical cores
        let cores = execute(
            "/usr/sbin/sysctl",
            ["-n", "hw.logicalcpu"]
        )
        check("Logical core detection", (Int(cores) ?? 0) > 0)

        // 4. Memory
        let memory = execute(
            "/usr/sbin/sysctl",
            ["-n", "hw.memsize"]
        )
        check("Memory detection", (Int64(memory) ?? 0) > 0)

        // 5. Storage
        let storage = execute("/bin/df", ["-h", "/"])
        check("Storage detection", storage.contains("/"))

        // 6. System tools
        let tools = [
            ("sw_vers", "/usr/bin/sw_vers"),
            ("sysctl", "/usr/sbin/sysctl"),
            ("df", "/bin/df"),
            ("otool", "/usr/bin/otool"),
            ("lipo", "/usr/bin/lipo")
        ]

        for (name, path) in tools {
            let exists = FileManager.default.isExecutableFile(
                atPath: path
            )
            check("System tool: \(name)", exists)
        }

        print("""

        ========================================
                    TEST SUMMARY
        ========================================

        PASSED: \(passed)
        FAILED: \(failed)
        TOTAL:  \(passed + failed)

        RESULT: \(failed == 0 ? "ALL TESTS PASSED" : "SOME TESTS FAILED")

        ========================================

        """)
    }

    private static func execute(
        _ path: String,
        _ arguments: [String]
    ) -> String {
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
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        } catch {
            return ""
        }
    }
}
