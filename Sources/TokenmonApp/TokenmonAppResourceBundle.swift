import Foundation

enum TokenmonAppResourceBundle {
    private static let bundleName = "Tokenmon_TokenmonApp.bundle"

    static let current: Bundle = {
        if let resourceURL = Bundle.main.resourceURL {
            let bundledURL = resourceURL.appendingPathComponent(bundleName)
            if let bundle = Bundle(url: bundledURL) {
                return bundle
            }
        }

        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        Swift.fatalError("could not load Tokenmon resource bundle from the app or build workspace")
        #endif
    }()
}
