public func looksLikeDialog(subrole: String?, resizable: Bool, hasFullscreenButton: Bool, isModal: Bool) -> Bool {
    subrole != "AXStandardWindow" || !resizable || !hasFullscreenButton || isModal
}

public func looksLikePopup(subrole: String?, hasWindowButtons: Bool) -> Bool {
    subrole == "AXUnknown" && !hasWindowButtons
}
