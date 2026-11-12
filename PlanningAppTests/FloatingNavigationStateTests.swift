import XCTest
@testable import PlanningApp

final class FloatingNavigationStateTests: XCTestCase {
    func testNavigationStartsExpanded() {
        XCTAssertFalse(FloatingNavigationState().isCollapsed)
    }

    func testDownwardScrollingCollapsesAfterThreshold() {
        var state = FloatingNavigationState()
        state.updateScrollOffset(0)
        state.updateScrollOffset(20)
        XCTAssertFalse(state.isCollapsed)
        state.updateScrollOffset(36)
        XCTAssertTrue(state.isCollapsed)
    }

    func testSmallScrollJitterDoesNotCollapseNavigation() {
        var state = FloatingNavigationState()
        [0, 6, 3, 8, 4, 9, 2].forEach { state.updateScrollOffset($0) }
        XCTAssertFalse(state.isCollapsed)
    }

    func testTopOverscrollDoesNotCountAsDownwardScrolling() {
        var state = FloatingNavigationState()
        [0, -70, -10, 0].forEach { state.updateScrollOffset($0) }
        XCTAssertFalse(state.isCollapsed)
    }

    func testFirstMeasurementEstablishesBaselineWithoutCollapsing() {
        var state = FloatingNavigationState()
        state.updateScrollOffset(300)
        XCTAssertFalse(state.isCollapsed)
        state.updateScrollOffset(336)
        XCTAssertTrue(state.isCollapsed)
    }

    func testUpwardScrollKeepsCollapsedNavigationCollapsed() {
        var state = FloatingNavigationState()
        [0, 80, 10, 0].forEach { state.updateScrollOffset($0) }
        XCTAssertTrue(state.isCollapsed)
    }

    func testExplicitExpansionRequiresFreshDownwardProgress() {
        var state = FloatingNavigationState()
        [0, 100].forEach { state.updateScrollOffset($0) }
        state.expand()
        state.updateScrollOffset(100)
        state.updateScrollOffset(110)
        XCTAssertFalse(state.isCollapsed)
        state.updateScrollOffset(136)
        XCTAssertTrue(state.isCollapsed)
    }

    func testUpwardScrollingEstablishesNewDownwardStartingPoint() {
        var state = FloatingNavigationState()
        state.updateScrollOffset(200)
        state.updateScrollOffset(170)
        state.updateScrollOffset(205)
        XCTAssertFalse(state.isCollapsed)
        state.updateScrollOffset(206)
        XCTAssertTrue(state.isCollapsed)
    }

    func testResetExpandsNavigationAndClearsPreviousScrollPosition() {
        var state = FloatingNavigationState()
        [0, 100].forEach { state.updateScrollOffset($0) }
        state.reset()
        state.updateScrollOffset(300)
        XCTAssertFalse(state.isCollapsed)
        state.updateScrollOffset(336)
        XCTAssertTrue(state.isCollapsed)
    }

    func testNonfiniteMeasurementsAreIgnored() {
        var state = FloatingNavigationState()
        [0, .nan, .infinity, -.infinity, 20].forEach { state.updateScrollOffset($0) }
        XCTAssertFalse(state.isCollapsed)
        state.updateScrollOffset(36)
        XCTAssertTrue(state.isCollapsed)
    }

    func testTabOrderMatchesNavigationDestinations() {
        XCTAssertEqual(PlanningTab.allCases, [.active, .completed, .archived, .settings])
        XCTAssertEqual(PlanningTab.settings.systemImage, "gearshape")
    }
}
