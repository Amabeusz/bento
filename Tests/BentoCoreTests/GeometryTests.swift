import Testing
@testable import BentoCore

@Test func insetShrinksAllSides() {
    #expect(Rect(x: 0, y: 0, w: 100, h: 50).inset(by: 10) == Rect(x: 10, y: 10, w: 80, h: 30))
}

@Test func intersectionNilWhenDisjoint() {
    #expect(Rect(x: 0, y: 0, w: 10, h: 10).intersection(Rect(x: 20, y: 0, w: 10, h: 10)) == nil)
}

@Test func intersectionOverlap() {
    #expect(Rect(x: 0, y: 0, w: 10, h: 10).intersection(Rect(x: 5, y: 5, w: 10, h: 10)) == Rect(x: 5, y: 5, w: 5, h: 5))
}

@Test func containsIsHalfOpen() {
    let r = Rect(x: 0, y: 0, w: 10, h: 10)
    #expect(r.contains(Point(x: 5, y: 5)))
    #expect(!r.contains(Point(x: 10, y: 5)))
}

@Test func centerIsMidpoint() {
    #expect(Rect(x: 0, y: 0, w: 10, h: 20).center == Point(x: 5, y: 10))
}
