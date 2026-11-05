import Foundation
import Testing
@testable import naiwa

/// settings.json 是指向 dotfiles 的软链接时，链接、真实文件的权限都要保住
extension HooksTests {
    /// 把 settings.json 换成指向 dotfiles/settings.json（权限 0600）的软链接
    func linkToDotfiles(_ file: URL, _ text: String) throws -> URL {
        let fm = FileManager.default
        let dotfiles = file.deletingLastPathComponent().appendingPathComponent("dotfiles")
        try fm.createDirectory(at: dotfiles, withIntermediateDirectories: true)
        let real = dotfiles.appendingPathComponent("settings.json")
        try text.write(to: real, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: real.path)
        try? fm.removeItem(at: file)
        try fm.createSymbolicLink(atPath: file.path, withDestinationPath: "dotfiles/settings.json")
        return real
    }

    func isLink(_ path: String) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: path)[.type] as? FileAttributeType) == .typeSymbolicLink
    }

    func mode(_ path: String) throws -> Int {
        try #require(FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? Int)
    }

    @Test func installKeepsSymlinkAndMode() throws {
        let original = "{\n  \"model\": \"opus\"\n}\n"
        try withSettings(nil) { file in
            let real = try linkToDotfiles(file, original)
            try Hooks.install()
            #expect(isLink(file.path))
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: file.path) == "dotfiles/settings.json")
            let text = try String(contentsOf: real, encoding: .utf8)
            #expect(isStrictJSON(text))
            #expect(Hooks.containsOurs(try Hooks.parse(text)))
            #expect(try mode(real.path) == 0o600)
            let backup = file.path + ".bak-naiwa"
            #expect(!isLink(backup))
            #expect(try String(contentsOfFile: backup, encoding: .utf8) == original)
        }
    }

    @Test func uninstallKeepsSymlinkAndMode() throws {
        let original = "{\n  \"model\": \"opus\"\n}\n"
        try withSettings(nil) { file in
            let real = try linkToDotfiles(file, original)
            try Hooks.install()
            try Hooks.uninstall()
            #expect(isLink(file.path))
            let text = try String(contentsOf: real, encoding: .utf8)
            #expect(isStrictJSON(text))
            #expect(!Hooks.containsOurs(try Hooks.parse(text)))
            #expect(try mode(real.path) == 0o600)
        }
    }

    /// 链接指向的文件还不存在（新装的 dotfiles）：在链接指向的位置新建，链接不动
    @Test func installThroughDanglingSymlink() throws {
        try withSettings(nil) { file in
            try FileManager.default.createSymbolicLink(atPath: file.path, withDestinationPath: "dotfiles/settings.json")
            try Hooks.install()
            #expect(isLink(file.path))
            let real = file.deletingLastPathComponent().appendingPathComponent("dotfiles/settings.json")
            let text = try String(contentsOf: real, encoding: .utf8)
            #expect(isStrictJSON(text))
            #expect(Hooks.containsOurs(try Hooks.parse(text)))
        }
    }
}
