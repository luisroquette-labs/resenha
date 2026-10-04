enum ResenhaDistributionChannel: String {
    case appStore
    case direct

    static var current: Self {
        #if RESENHA_APP_STORE
        .appStore
        #else
        .direct
        #endif
    }

    var usesSandboxedTextService: Bool { self == .appStore }
    var requiresAccessibility: Bool { self == .direct }
}
