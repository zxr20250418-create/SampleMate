import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let sampleMateBackup = UTType(exportedAs: "com.zxr.samplemate.backup")
}

struct SampleMateBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.sampleMateBackup] }
    static var writableContentTypes: [UTType] { [.sampleMateBackup] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        let wrapper = configuration.file
        if wrapper.isDirectory {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = wrapper.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
