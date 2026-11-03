public func looksLikeDialog(subrole: String?, resizable: Bool, hasFullscreenButton: Bool, isModal: Bool) -> Bool {
    subrole != "AXStandardWindow" || !resizable || !hasFullscreenButton || isModal
}
