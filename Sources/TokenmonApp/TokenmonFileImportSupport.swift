import Foundation
import UniformTypeIdentifiers

enum TokenmonFileImportRequirement: Equatable {
    case file
    case directory

    var allowedContentTypes: [UTType] {
        switch self {
        case .file:
            return [.item]
        case .directory:
            return [.folder]
        }
    }

    func matches(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        let isDirectory = values?.isDirectory ?? url.hasDirectoryPath

        switch self {
        case .file:
            return isDirectory == false
        case .directory:
            return isDirectory == true
        }
    }
}

enum TokenmonFileImportOutcome: Equatable {
    case imported(String)
    case cancelled
    case failure(String)
}

enum TokenmonFileImportSupport {
    static func resolve(
        result: Result<URL, Error>,
        requirement: TokenmonFileImportRequirement,
        invalidSelectionMessage: String
    ) -> TokenmonFileImportOutcome {
        switch result {
        case .success(let url):
            guard requirement.matches(url) else {
                return .failure(invalidSelectionMessage)
            }
            return .imported(url.path)
        case .failure(let error):
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain, nsError.code == NSUserCancelledError {
                return .cancelled
            }
            return .failure(error.localizedDescription)
        }
    }
}
