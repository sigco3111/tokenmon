import TokenmonDomain

public enum TokenmonGameEngineModule {
    public static let name = "TokenmonGameEngine"
    public static let dependsOn = TokenmonDomainModule.name
    public static let summary = "Gameplay shell over provider-neutral domain types and exploration bookkeeping"
}
