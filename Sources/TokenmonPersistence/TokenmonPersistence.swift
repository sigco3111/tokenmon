import TokenmonDomain

public enum TokenmonPersistenceModule {
    public static let name = "TokenmonPersistence"
    public static let dependsOn = "\(TokenmonDomainModule.name)+TokenmonProviders"
    public static let summary = "SQLite bootstrap, migrations, species seeding, and usage ingestion"
}
