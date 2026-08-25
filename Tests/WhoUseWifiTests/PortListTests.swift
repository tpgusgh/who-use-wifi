import XCTest
@testable import WhoUseWifi

final class PortListTests: XCTestCase {
    func testCommonPortsNoDuplicates() {
        XCTAssertEqual(Set(CommonPorts.list).count, CommonPorts.list.count)
    }

    func testCommonPortsIncludesWebDefaults() {
        XCTAssertTrue(CommonPorts.list.contains(80))
        XCTAssertTrue(CommonPorts.list.contains(443))
        XCTAssertTrue(CommonPorts.list.contains(8080))
    }
}
