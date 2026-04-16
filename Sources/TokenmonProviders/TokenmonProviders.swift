import TokenmonDomain

public enum TokenmonProvidersModule {
    public static let name = "TokenmonProviders"
    public static let dependsOn = TokenmonDomainModule.name
    public static let summary = "Provider adapter shell, inbox reader, and normalized usage events"
}
