//
//  MotivationRunTests.swift
//  MotivationRunTests
//
//  Created by 주장규 on 2/10/26.
//

import XCTest
@testable import MotivationRun

final class MotivationRunTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testRunJournalEntryRoundTrip() throws {
        let original = RunJournalEntry(difficulty: 0.75, diary: "힘들었지만 완주!", updatedAt: Date(timeIntervalSince1970: 0))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RunJournalEntry.self, from: data)
        XCTAssertEqual(decoded.difficulty, 0.75)
        XCTAssertEqual(decoded.diary, "힘들었지만 완주!")
        XCTAssertEqual(decoded.updatedAt, Date(timeIntervalSince1970: 0))
    }

    func testRunSessionDecodesWithoutHkWorkoutID() throws {
        // 구형 JSON에 hkWorkoutID 없어도 nil로 복원되어야 함
        let json = """
        {"id":"E621E1F8-C36C-495A-93FC-0C247A3E6E5F","date":0,"distanceKm":3.5,"calories":200,"durationMinutes":30}
        """
        let data = json.data(using: .utf8)!
        let session = try JSONDecoder().decode(RunSession.self, from: data)
        XCTAssertNil(session.hkWorkoutID)
        XCTAssertEqual(session.distanceKm, 3.5)
    }

    // MARK: - remainingDaysInMonth (오늘 포함)

    private func makeDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, cal: Calendar) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h
        return cal.date(from: comps)!
    }

    private var testCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal
    }

    func testRemainingDaysMidMonthIncludesToday() throws {
        let cal = testCalendar
        // 6/15 → 오늘 포함 16일 (15~30)
        let date = makeDate(2026, 6, 15, 12, cal: cal)
        XCTAssertEqual(remainingDaysInMonth(from: date, calendar: cal), 16)
    }

    func testRemainingDaysLastDayIsOne() throws {
        let cal = testCalendar
        // 6/30 23시 → 오늘만 남음 = 1
        let date = makeDate(2026, 6, 30, 23, cal: cal)
        XCTAssertEqual(remainingDaysInMonth(from: date, calendar: cal), 1)
    }

    func testRemainingDaysFirstDayIsFullMonth() throws {
        let cal = testCalendar
        // 6/1 00시 → 6월 전체 30일
        let date = makeDate(2026, 6, 1, 0, cal: cal)
        XCTAssertEqual(remainingDaysInMonth(from: date, calendar: cal), 30)
    }

    func testRemainingDaysTimeOfDayIrrelevant() throws {
        let cal = testCalendar
        let early = remainingDaysInMonth(from: makeDate(2026, 6, 15, 0, cal: cal), calendar: cal)
        let late  = remainingDaysInMonth(from: makeDate(2026, 6, 15, 23, cal: cal), calendar: cal)
        XCTAssertEqual(early, late)
        XCTAssertEqual(early, 16)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    // MARK: - ThemeStore fallback (1번: 기존 기본값 유지)

    func testThemeFallbackDefaultsMatchLegacy() throws {
        XCTAssertEqual(ThemeStore.fallbackAccent(raw: nil), .blue)
        XCTAssertEqual(ThemeStore.fallbackBackground(raw: nil), .white)
        XCTAssertEqual(ThemeStore.fallbackAccent(raw: "nonsense"), .blue)
        XCTAssertEqual(ThemeStore.fallbackBackground(raw: "nonsense"), .white)
        for accent in ThemeAccent.allCases {
            XCTAssertEqual(ThemeStore.fallbackAccent(raw: accent.rawValue), accent)
        }
        for background in ThemeBackground.allCases {
            XCTAssertEqual(ThemeStore.fallbackBackground(raw: background.rawValue), background)
        }
    }

    func testThemeBackgroundCaseCountUnchanged() throws {
        // 새 케이스 추가는 기존 사용자의 저장값·위젯에 영향을 주므로 명시적 결정 필요
        XCTAssertEqual(ThemeBackground.allCases.count, 2)
    }

    func testResetPreservesProEntitlement() throws {
        XCTAssertFalse(SharedDataManager.resettableKeys.contains("isPro"))
        XCTAssertTrue(SharedDataManager.resettableKeys.contains("themeAccent"))
        XCTAssertTrue(SharedDataManager.resettableKeys.contains("themeBackground"))
        XCTAssertTrue(SharedDataManager.resettableKeys.contains("journalEntries"))
        XCTAssertTrue(SharedDataManager.resettableKeys.contains("galleryImageIDs"))
    }

    func testThemeStoreExplicitInit() throws {
        let store = ThemeStore(accent: .green, background: .black)
        XCTAssertEqual(store.accent, .green)
        XCTAssertEqual(store.background, .black)
        XCTAssertEqual(store.tokens.background, .black)
    }

}
