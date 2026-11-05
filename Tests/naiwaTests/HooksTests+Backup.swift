import Foundation
import Testing
@testable import naiwa

extension HooksTests {
    /// 不是 UTF-8 的 settings.json：报错，一个字节都不动，也不留备份
    @Test func installRefusesNonUTF8() throws {
        try withSettings(nil) { file in
            let bytes = Data([0x7B, 0x22, 0x61, 0x22, 0x3A, 0x20, 0x22, 0xFF, 0xFE, 0x22, 0x7D, 0x0A])
            try bytes.write(to: file)
            #expect(throws: Hooks.Failure.self) { try Hooks.install() }
            #expect(try Data(contentsOf: file) == bytes)
            #expect(!FileManager.default.fileExists(atPath: file.path + ".bak-naiwa"))
        }
    }

    /// 没有 settings.json：照常从空对象装
    @Test func installCreatesMissingFile() throws {
        try withSettings(nil) { file in
            try Hooks.install()
            let text = try String(contentsOf: file, encoding: .utf8)
            #expect(isStrictJSON(text))
            #expect(Hooks.containsOurs(try Hooks.parse(text)))
            #expect(!FileManager.default.fileExists(atPath: file.path + ".bak-naiwa"))
        }
    }

    /// 备份只留第一次的原文件，装、撤、再装都不覆盖
    @Test func installKeepsFirstBackup() throws {
        let original = "{\n  \"model\": \"opus\"\n}\n"
        try withSettings(original) { file in
            let backup = file.path + ".bak-naiwa"
            try Hooks.install()
            #expect(try String(contentsOfFile: backup, encoding: .utf8) == original)
            try Hooks.uninstall()
            try Hooks.install()
            #expect(try String(contentsOfFile: backup, encoding: .utf8) == original)
        }
    }
}
