@_exported import TextDiffCore
@_exported import TextDiffUICommon

#if os(macOS)
@_exported import TextDiffMacOSUI
#elseif os(iOS)
@_exported import TextDiffIOSUI
#endif
