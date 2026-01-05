import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let sampleMateBackup = UTType(exportedAs: "com.zxr.samplemate.backup")
}

final class FileWrapperBox: @unchecked Sendable {
    let value: FileWrapper

    init(_ value: FileWrapper) {
        self.value = value
    }
}

struct SampleMateBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.sampleMateBackup] }
    static var writableContentTypes: [UTType] { [.sampleMateBackup] }

    var rootFileWrapper: FileWrapperBox

    init(rootFileWrapper: FileWrapper = FileWrapper(directoryWithFileWrappers: [:])) {
        self.rootFileWrapper = FileWrapperBox(rootFileWrapper)
    }

    init(configuration: ReadConfiguration) throws {
        let wrapper = configuration.file
        rootFileWrapper = FileWrapperBox(wrapper)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        rootFileWrapper.value
    }
}
