import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let sampleMateBackup = UTType(exportedAs: "com.zxr.samplemate.backup")
}

struct SampleMateBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.sampleMateBackup] }
    static var writableContentTypes: [UTType] { [.sampleMateBackup] }

    var rootFileWrapper: FileWrapper

    init(rootFileWrapper: FileWrapper = FileWrapper(directoryWithFileWrappers: [:])) {
        self.rootFileWrapper = rootFileWrapper
    }

    init(configuration: ReadConfiguration) throws {
        guard let wrapper = configuration.file else {
            throw CocoaError(.fileReadCorruptFile)
        }
        rootFileWrapper = wrapper
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        rootFileWrapper
    }
}
