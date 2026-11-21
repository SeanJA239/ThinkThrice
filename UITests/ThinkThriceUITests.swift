import XCTest

/// End-to-end checks of the demo in the simulator, run with the ThinkThrice
/// scheme's Test action (see docs/HANDOFF.md → UI tests).
///
/// Every test launches with `THINKTHRICE_RESET=1`, so the app starts from the
/// seed conversations and default settings whatever earlier tests left behind.
/// Screenshots of each step go to `/tmp/shots` on the Mac (the simulator writes
/// to the host's file system); set `THINKTHRICE_SHOTS` in the scheme to change it.
/// The tests tap the English 「Allow」 on the notification prompt, so run them
/// on a simulator in English.
final class ThinkThriceUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launchEnvironment["THINKTHRICE_RESET"] = "1"
    }

    func shot(_ name: String) {
        let dir = ProcessInfo.processInfo.environment["THINKTHRICE_SHOTS"] ?? "/tmp/shots"
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? data.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func allowNotifications() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 4) { allow.tap() }
    }

    func element(beginningWith prefix: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    func send(_ text: String) {
        let field = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)
        app.buttons["发送"].tap()
    }

    func openDebug() {
        let header = app.descendants(matching: .any)["chatHeader"].firstMatch
        header.press(forDuration: 1.2)
        XCTAssertTrue(app.navigationBars["演示面板"].waitForExistence(timeout: 3))
    }

    func closeSheet() {
        app.navigationBars["演示面板"].buttons["完成"].tap()
        sleep(1)
    }

    func testFlow() {
        app.launch()
        allowNotifications()
        shot("00-list")
        app.staticTexts["前任"].firstMatch.tap()
        sleep(1)
        // Start from a known daytime regardless of the simulator's clock.
        openDebug()
        app.buttons["快进到 09:00（早上）"].tap()
        closeSheet()

        // Calm message is delivered and the scripted peer replies.
        send("晚上好")
        usleep(600_000)
        shot("01a-header-typing")
        sleep(3)
        shot("01-delivered-and-reply")

        // Day: an impulsive message settles for about 15 minutes.
        send("你给我滚，我受够你了！")
        let settling = element(beginningWith: "冷静中的消息")
        XCTAssertTrue(settling.waitForExistence(timeout: 5))
        sleep(1)
        shot("02-settling-day")

        settling.tap()
        XCTAssertTrue(app.staticTexts["这条消息正在冷静"].waitForExistence(timeout: 3))
        shot("03-action-panel")

        // Rewrite: pieces appear one by one; cancel keeps the original.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '改写'")).firstMatch.tap()
        sleep(1)
        shot("04-melt-start")
        sleep(3)
        shot("05-melt-revealed")
        app.buttons["取消"].tap()
        sleep(1)

        // Ritual by day: one page, locked for three 5 s breaths, then deliver.
        element(beginningWith: "冷静中的消息").tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '现在就要发'")).firstMatch.tap()
        sleep(1)
        shot("06-ritual-locked")
        XCTAssertFalse(app.buttons["仍然发送"].isEnabled)
        sleep(16)
        XCTAssertTrue(app.buttons["仍然发送"].isEnabled)
        app.buttons["仍然发送"].tap()
        sleep(3)
        shot("07-ritual-delivered")

        // Night: jump the demo clock to 1:30.
        openDebug()
        app.buttons["跳到 01:30（深夜）"].tap()
        sleep(1)
        shot("08-debug-panel")
        closeSheet()
        send("我真的好想你，我们复合好不好")
        XCTAssertTrue(element(beginningWith: "冷静中的消息").waitForExistence(timeout: 5))
        sleep(1)
        shot("09-settling-night")

        // Persistence: kill and relaunch; the settling message and the demo time come back.
        app.terminate()
        app.launchEnvironment["THINKTHRICE_RESET"] = nil
        app.launch()
        app.staticTexts["前任"].firstMatch.tap()
        XCTAssertTrue(element(beginningWith: "冷静中的消息").waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '演示时间'")).firstMatch.exists)
        sleep(1)
        shot("09a-after-relaunch")

        // Night ritual has three pages; abandon on page one.
        element(beginningWith: "冷静中的消息").tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '当晚就要发'")).firstMatch.tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["第 1 / 3 题"].waitForExistence(timeout: 3))
        shot("10-ritual-night")
        app.buttons["算了"].tap()
        sleep(1)
        XCTAssertTrue(element(beginningWith: "冷静中的消息").exists)

        // Morning: fast-forward to 9:00, the bubble becomes ready, confirm and send.
        openDebug()
        app.buttons["快进到 09:00（早上）"].tap()
        sleep(1)
        closeSheet()
        sleep(2)
        shot("11-ready")
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '冷静好了'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["发送"].firstMatch.waitForExistence(timeout: 3))
        shot("12-confirm")
        app.buttons.matching(NSPredicate(format: "label == '发送'")).element(boundBy: 0).tap()
        usleep(450_000)
        shot("12a-delivering")
        usleep(500_000)
        shot("12b-delivering")
        sleep(3)
        shot("13-morning-delivered")

        // Rewrite that calms down is delivered as a reward.
        send("你从来都不在乎我，我真是受够了！")
        XCTAssertTrue(element(beginningWith: "冷静中的消息").waitForExistence(timeout: 5))
        element(beginningWith: "冷静中的消息").tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '改写'")).firstMatch.tap()
        sleep(1)
        let editor = app.textViews.firstMatch
        editor.tap()
        editor.press(forDuration: 1.2)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        editor.typeText("我有点难过，我们明天好好聊聊吧")
        sleep(1)
        shot("14-melt-edited")
        app.buttons["重新判断"].tap()
        sleep(1)
        shot("15-rewrite-reward")
        sleep(2)

        // Let go: zero friction, the bubble dissolves.
        send("你有病吧")
        XCTAssertTrue(element(beginningWith: "冷静中的消息").waitForExistence(timeout: 5))
        element(beginningWith: "冷静中的消息").tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '放下'")).firstMatch.tap()
        usleep(500_000)
        shot("16-dissolving")
        sleep(3)
        XCTAssertFalse(element(beginningWith: "冷静中的消息").exists)
        shot("17-after-let-go")
    }

    func testTwoPhoneEntry() {
        app.launch()
        allowNotifications()
        app.staticTexts["前任"].firstMatch.tap()
        sleep(1)
        openDebug()
        app.swipeUp()
        app.buttons["等待连接"].tap()
        sleep(1)
        shot("20-debug-two-phone")
        closeSheet()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["附近的 TA"].waitForExistence(timeout: 3))
        shot("21-list-with-nearby")
        app.staticTexts["附近的 TA"].tap()
        sleep(2)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        shot("22-nearby-searching")
        if springboard.buttons["Allow"].exists { springboard.buttons["Allow"].tap() }
        sleep(1)
        shot("23-nearby-after-permission")
        openDebugFrom(header: true)
        app.buttons["关闭"].tap()
        closeSheet()
    }

    func openDebugFrom(header: Bool) {
        let header = app.descendants(matching: .any)["chatHeader"].firstMatch
        header.press(forDuration: 1.2)
        XCTAssertTrue(app.navigationBars["演示面板"].waitForExistence(timeout: 3))
        app.swipeUp()
    }

    func testDetectorProbe() {
        app.launch()
        allowNotifications()
        app.staticTexts["前任"].firstMatch.tap()
        sleep(1)
        openDebug()
        app.swipeUp()
        app.swipeUp()
        let probe = app.descendants(matching: .any).matching(NSPredicate(format: "placeholderValue == '输入一句话试试'")).firstMatch
        XCTAssertTrue(probe.waitForExistence(timeout: 3))
        probe.tap()
        probe.typeText("你怎么总是不回我，我受够了！！")
        app.swipeUp()
        sleep(1)
        shot("30-keyword-probe")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '受够'")).firstMatch.exists)
    }

    /// A paced run through the demo for the backup recording, with shots at the animation moments.
    func testDemoRecording() {
        app.launch()
        allowNotifications()
        sleep(2)
        shot("40-list")
        app.staticTexts["前任"].firstMatch.tap()
        sleep(2)
        openDebug()
        app.buttons["跳到 01:30（深夜）"].tap()
        sleep(1)
        closeSheet()
        sleep(2)
        shot("41-night-sky")
        send("晚上好")
        sleep(4)
        send("我真的好想你，我们复合好不好")
        usleep(150_000)
        shot("42-freeze-start")
        usleep(350_000)
        shot("43-freeze-mid")
        sleep(3)
        shot("44-frozen")
        app.navigationBars.buttons.firstMatch.tap()
        sleep(2)
        shot("44a-list-held-badge")
        app.staticTexts["前任"].firstMatch.tap()
        sleep(2)
        element(beginningWith: "冷静中的消息").tap()
        sleep(2)
        shot("45-action-panel-reason")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '改写'")).firstMatch.tap()
        usleep(1_000_000)
        shot("46-melt-thawing")
        sleep(3)
        shot("47-melt-thawed")
        app.buttons["取消"].tap()
        sleep(1)
        element(beginningWith: "冷静中的消息").tap()
        sleep(1)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '当晚就要发'")).firstMatch.tap()
        usleep(1_200_000)
        shot("48-ritual-inhale")
        sleep(2)
        shot("49-ritual-exhale")
        sleep(13)
        shot("50-ritual-unlocked")
        app.buttons["算了"].tap()
        sleep(2)
        openDebug()
        app.buttons["快进到 09:00（早上）"].tap()
        sleep(1)
        closeSheet()
        sleep(3)
        shot("51-morning-ready")
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '冷静好了'")).firstMatch.tap()
        sleep(2)
        app.buttons.matching(NSPredicate(format: "label == '发送'")).element(boundBy: 0).tap()
        usleep(600_000)
        shot("52-thaw-to-solid")
        sleep(4)
        send("你有病吧，我受够了")
        sleep(3)
        element(beginningWith: "冷静中的消息").tap()
        sleep(2)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '放下'")).firstMatch.tap()
        usleep(500_000)
        shot("53-dissolve")
        sleep(3)
        shot("54-after-dissolve")
        app.navigationBars.buttons.firstMatch.tap()
        sleep(2)
        shot("55-list-after")
        XCUIDevice.shared.press(.home)
        sleep(2)
        shot("56-home-icon")
    }

    func testTour() {
        app.launch()
        allowNotifications()
        sleep(2)
        XCTAssertTrue(app.staticTexts["组员"].exists)
        shot("60-chats-tab")
        app.buttons["个人主页"].tap()
        sleep(2)
        shot("61-profile")
        app.buttons["完成"].firstMatch.tap()
        sleep(1)
        app.tabBars.buttons["三思"].tap()
        sleep(2)
        shot("62-stats")
        app.swipeUp()
        sleep(1)
        shot("62b-stats-lower")
        app.tabBars.buttons["设置"].tap()
        sleep(2)
        shot("63-settings")
        app.tabBars.buttons["聊天"].tap()
        sleep(1)
        app.staticTexts["前任"].firstMatch.tap()
        sleep(2)
        openDebug()
        app.buttons["快进到 09:00（早上）"].tap()
        closeSheet()
        sleep(2)
        shot("64-chat-day-no-snow")
        app.descendants(matching: .any)["chatHeader"].firstMatch.tap()
        usleep(150_000)
        shot("65-card-expanding")
        sleep(2)
        shot("65a-contact-card")
        let card = app.descendants(matching: .any)["contactPanel"].firstMatch
        XCTAssertTrue(card.exists)
        let note = app.descendants(matching: .any).matching(NSPredicate(format: "placeholderValue == '前任'")).firstMatch
        note.tap()
        note.typeText("小A")
        sleep(2)
        shot("65b-contact-card-keyboard")
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.exists)
        XCTAssertLessThanOrEqual(card.frame.maxY, keyboard.frame.minY, "card bottom \(card.frame.maxY) keyboard top \(keyboard.frame.minY)")
        note.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2))
        app.buttons["收起"].tap()
        sleep(1)
        // Keyboard already up from the chat input, then open the card from the capsule.
        let input = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
        input.tap()
        sleep(1)
        app.descendants(matching: .any)["chatHeader"].firstMatch.tap()
        sleep(2)
        shot("65c-card-over-keyboard")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertLessThanOrEqual(card.frame.maxY, app.keyboards.firstMatch.frame.minY)
        app.buttons["收起"].tap()
        sleep(1)
        app.buttons["冷静 15 分钟"].tap()
        sleep(1)
        app.buttons["开始冷静"].tap()
        sleep(2)
        shot("66-cooling")
        send("好吧我再想想")
        sleep(3)
        shot("67-cooling-held-snow")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '冷静中，'")).firstMatch.tap()
        sleep(1)
        app.buttons["结束冷静"].tap()
        sleep(3)
        shot("68-cooling-ended")
        openDebug()
        app.buttons["跳到 01:30（深夜）"].tap()
        closeSheet()
        send("你根本不在乎我，我受够了")
        sleep(4)
        shot("69-night-snow")
        element(beginningWith: "冷静中的消息").tap()
        sleep(1)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '当晚就要发'")).firstMatch.tap()
        usleep(1_400_000)
        shot("70-flower-inhale")
        sleep(1)
        shot("71-flower-full")
        sleep(2)
        shot("72-flower-exhale")
    }

    func testStatsReview() {
        app.launch()
        allowNotifications()
        sleep(1)
        app.tabBars.buttons["三思"].tap()
        sleep(2)
        shot("80-review-top")
        app.swipeUp()
        sleep(1)
        shot("81-review-lower")
        app.tabBars.buttons["设置"].tap()
        sleep(1)
        app.swipeUp()
        app.buttons["清除示例统计"].tap()
        sleep(1)
        app.tabBars.buttons["三思"].tap()
        sleep(1)
        app.swipeDown()
        sleep(1)
        shot("82-review-empty")
    }

    /// Opens and folds the contact card twice; record the simulator while it runs to see the animation.
    func testCardClip() {
        app.launch()
        allowNotifications()
        app.staticTexts["前任"].firstMatch.tap()
        sleep(2)
        let header = app.descendants(matching: .any)["chatHeader"].firstMatch
        header.tap()
        sleep(2)
        app.buttons["收起"].tap()
        sleep(1)
        header.tap()
        sleep(2)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92)).tap()
        sleep(2)
    }

    func testSearch() {
        app.launch()
        allowNotifications()
        sleep(1)
        let field = app.textFields["contactSearch"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        shot("90-search-empty")
        field.tap()
        field.typeText("老板")
        sleep(1)
        XCTAssertTrue(app.staticTexts["老板"].exists)
        XCTAssertFalse(app.staticTexts["组员"].exists)
        shot("91-search-boss")
        field.typeText("xyz")
        sleep(1)
        shot("92-search-none")
    }
}
