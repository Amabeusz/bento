import BentoCore
import Foundation

@_silgen_name("SLSMainConnectionID")
private func SLSMainConnectionID() -> Int32
@_silgen_name("SLSWindowQueryWindows")
private func SLSWindowQueryWindows(_ cid: Int32, _ windows: CFArray, _ options: UInt32) -> Unmanaged<CFTypeRef>?
@_silgen_name("SLSWindowQueryResultCopyWindows")
private func SLSWindowQueryResultCopyWindows(_ query: CFTypeRef) -> Unmanaged<CFTypeRef>?
@_silgen_name("SLSWindowIteratorAdvance")
private func SLSWindowIteratorAdvance(_ iterator: CFTypeRef) -> Bool
@_silgen_name("SLSWindowIteratorGetWindowID")
private func SLSWindowIteratorGetWindowID(_ iterator: CFTypeRef) -> UInt32
@_silgen_name("SLSWindowIteratorGetResolvedCornerRadii")
private func SLSWindowIteratorGetResolvedCornerRadii(_ iterator: CFTypeRef) -> Unmanaged<CFArray>?

func windowCornerRadii(_ ids: [WindowID]) -> [WindowID: Double] {
    guard !ids.isEmpty,
          let query = SLSWindowQueryWindows(SLSMainConnectionID(), ids.map { NSNumber(value: $0) } as CFArray, 0)?
              .takeRetainedValue(),
          let iterator = SLSWindowQueryResultCopyWindows(query)?.takeRetainedValue()
    else { return [:] }
    var radii: [WindowID: Double] = [:]
    while SLSWindowIteratorAdvance(iterator) {
        let id = SLSWindowIteratorGetWindowID(iterator)
        if let corners = SLSWindowIteratorGetResolvedCornerRadii(iterator)?.takeRetainedValue() as? [Double],
           let radius = corners.max() {
            radii[id] = radius
        }
    }
    return radii
}
