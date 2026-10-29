import XCTest

/// 条件が成り立つまで待つ。上限は hang guard で、待ちの長さを合否にしない
/// (SwiftUI の反映や自動消去のタイマーは次の run loop 以降に来る)。
@MainActor
func waitUntil(
    _ what: String,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: () -> Bool
) async throws {
    for _ in 0..<200 where !condition() {
        try await Task.sleep(for: .milliseconds(20))
    }
    XCTAssertTrue(condition(), what, file: file, line: line)
}
