import XCTest
@testable import WhoUseWifi

final class NetworkInfoTests: XCTestCase {
    func testSubnetHostsCoversFullRange() {
        let hosts = NetworkInfo.subnetHosts(fromIP: "192.168.0.42")
        XCTAssertEqual(hosts.count, 254)
        XCTAssertEqual(hosts.first, "192.168.0.1")
        XCTAssertEqual(hosts.last, "192.168.0.254")
    }

    func testSubnetHostsInvalidIP() {
        XCTAssertEqual(NetworkInfo.subnetHosts(fromIP: "not-an-ip"), [])
    }
}
