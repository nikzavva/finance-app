import XCTest
@testable import finance_app

final class TransactionTests: XCTestCase {
    func testParseValidJSONObject() {
        let json: [String: Any] = [
            "id": 1,
            "accountId": 2,
            "categoryId": 3,
            "amount": "150.50",
            "transactionDate": "2026-07-11T14:56:59Z",
            "comment": "Test comment",
            "createdAt": "2026-07-11T14:56:59Z",
            "updatedAt": "2026-07-11T14:56:59Z",
            "direction": "income"
        ]
        let transaction = Transaction.parse(jsonObject: json)
        XCTAssertNotNil(transaction)
        XCTAssertEqual(transaction?.id, 1)
        XCTAssertEqual(transaction?.accountId, 2)
        XCTAssertEqual(transaction?.categoryId, 3)
        XCTAssertEqual(transaction?.amount, Decimal(string: "150.50"))
        XCTAssertEqual(transaction?.comment, "Test comment")
        XCTAssertEqual(transaction?.direction, .income)
    }
    
    func testParseInvalidJSONObject() {
        let json: [String: Any] = [
            "id": "invalid",
            "accountId": 2,
            "categoryId": 3,
            "amount": "150.50",
            "transactionDate": "2026-07-11T14:56:59Z",
            "direction": "income"
        ]
        let transaction = Transaction.parse(jsonObject: json)
        XCTAssertNil(transaction)
    }
    
    func testJSONObjectConversion() {
        let transaction = Transaction(
            id: 1,
            accountId: 2,
            categoryId: 3,
            amount: Decimal(string: "150.50")!,
            transactionDate: ISO8601DateFormatter().date(from: "2026-07-11T14:56:59Z")!,
            comment: "Test",
            createdAt: "2026-07-11T14:56:59Z",
            updatedAt: "2026-07-11T14:56:59Z",
            direction: .income
        )
        let jsonObject = transaction.jsonObject
        guard let dict = jsonObject as? [String: Any] else {
            XCTFail("jsonObject should be a dictionary")
            return
        }
        XCTAssertEqual(dict["id"] as? Int, 1)
        XCTAssertEqual(dict["accountId"] as? Int, 2)
        XCTAssertEqual(dict["categoryId"] as? Int, 3)
        XCTAssertEqual(dict["amount"] as? String, "150.5")
        XCTAssertEqual(dict["comment"] as? String, "Test")
        XCTAssertEqual(dict["direction"] as? String, "income")
    }
}
