import Foundation

enum TokenmonAppResourceLocator {
    static func resourceURL(relativePath: String) -> URL? {
        let fm = FileManager.default

        if let bundled = TokenmonAppResourceBundle.current.resourceURL?.appendingPathComponent(relativePath),
           fm.fileExists(atPath: bundled.path)
        {
            return bundled
        }

        if let flat = Bundle.main.resourceURL?.appendingPathComponent(relativePath),
           fm.fileExists(atPath: flat.path)
        {
            return flat
        }

        return nil
    }
}
