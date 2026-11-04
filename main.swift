import Cocoa

let green = NSColor(srgbRed: 0.74, green: 1, blue: 0.42, alpha: 1)
let muted = NSColor(srgbRed: 0.60, green: 0.65, blue: 0.56, alpha: 1)
var lines: [String] { [L("忍忍，别和钱过不去。"), L("来都来了，赚点再走。"), L("工作可以没头绪，工资不能没着落。"), L("今天的忍耐，明天的外卖。"), L("先别掀桌，桌上还有工资。"), L("人可以放空，工资照常到账。"), L("上班图什么？图银行卡多个零。"), L("先把钱挣了，其他的下班再说。"), L("你以为我在上班？我在攒不上班的钱。"), L("离财务自由还远，离下班已经近了。"), L("情绪先放一放，钱要一分分赚。"), L("这一秒的班，是下一口饭的底气。"), L("今天也在为想买就买添砖加瓦。"), L("不想上班是真的，想要工资也是真的。"), L("稳住，这会儿还在进账。"), L("给生活低个头，给余额抬个头。"), L("今天多坐一会儿，周末多点一道菜。"), L("上班时想开点，发薪时想买点。"), L("先赚今天的钱，再做明天的梦。"), L("班可以上得勉强，工资必须领得坦荡。")] }

struct WorkState: Codable {
    var salary: Double = 0
    var elapsed: Double = 0
    var start: Double? = nil
    var mode = "idle"
    var fullDay = false
    mutating func setWorkedTime(_ seconds:Double,limit:Double,keepRunning:Bool,now:Double=Date().timeIntervalSince1970) {
        guard seconds.isFinite && limit.isFinite && limit>0 else { return }
        elapsed=min(limit,max(0,seconds));fullDay=elapsed>=limit
        if fullDay { mode="done";start=nil }
        else if keepRunning { mode="running";start=now }
        else { if mode != "stopped" {mode="paused"};start=nil }
    }
    func duration(_ now: Double = Date().timeIntervalSince1970, limit: Double = 28800) -> Double {
        min(limit, max(0, elapsed + (mode == "running" ? max(0, now - (start ?? now)) : 0)))
    }
}
func clock(_ seconds: Double) -> String {
    let n = Int(seconds)
    return String(format: "%02d:%02d:%02d", n / 3600, n / 60 % 60, n % 60)
}

final class MeterView: NSView {
    override var isFlipped: Bool { true }
    let title = NSTextField(labelWithString: L("今日已赚"))
    let status = NSTextField(labelWithString: L("准备上班"))
    let amount = NSTextField(labelWithString: "¥0.000")
    let rates = NSTextField(labelWithString: "")
    let elapsed = NSTextField(labelWithString: "")
    let remaining = NSTextField(labelWithString: "")
    let quote = NSTextField(labelWithString: lines.randomElement()!)
    let salary = NSButton(title: L("设置月薪"), target: nil, action: nil)
    let action = NSButton(title: L("开始上班"), target: nil, action: nil)
    let stop = NSButton(title: L("停止计时"), target: nil, action: nil)
    let finish = NSButton(title: L("下班"), target: nil, action: nil)
    let reset = NSButton(title: L("重新开始"), target: nil, action: nil)
    let shuffle = NSButton(title: L("换一句 ↻"), target: nil, action: nil)
    let settingsButton = NSButton(title: L("修改工资"), target: nil, action: nil)
    let calendarButton = NSButton(title: L("上班记录"), target: nil, action: nil)
    let track = PunchSlider(value:0,minValue:0,maxValue:1,target:nil,action:nil)
    var progress: Double = 0 { didSet { if !track.isScrubbing {track.doubleValue=progress} } }
    override init(frame: NSRect) {
        super.init(frame: frame)
        appearance = NSAppearance(named: .darkAqua)
        wantsLayer = true
        layer?.backgroundColor = NSColor(srgbRed: 0.10, green: 0.13, blue: 0.085, alpha: 1).cgColor
        for label in [title, status, rates, elapsed, remaining, quote] {
            label.font = .systemFont(ofSize: 10)
            label.textColor = muted
            label.maximumNumberOfLines = 1
            label.lineBreakMode = .byTruncatingTail
            addSubview(label)
        }
        status.textColor = green
        status.alignment = .right
        remaining.alignment = .right
        amount.font = .monospacedDigitSystemFont(ofSize: 46, weight: .medium)
        amount.textColor = green
        amount.maximumNumberOfLines = 1
        addSubview(amount)
        for button in [salary, action, stop, finish, reset, shuffle, settingsButton, calendarButton] {
            button.font = .systemFont(ofSize: 10)
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.contentTintColor = muted
            addSubview(button)
        }
        action.contentTintColor = green
        salary.bezelStyle = .inline
        reset.bezelStyle = .inline
        shuffle.bezelStyle = .inline
        for button in [salary, action, stop, finish, reset, shuffle, settingsButton, calendarButton] {
            button.isBordered = false
            button.wantsLayer = true
            button.layer?.cornerRadius = 5
            button.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.07).cgColor
        }
        action.layer?.backgroundColor = green.withAlphaComponent(0.15).cgColor
        track.cell=GreenSliderCell();track.minValue=0;track.maxValue=1
        track.isContinuous=true
        track.controlSize = .small
        track.toolTip=L("拖动补卡：设置今日已上班时长，收入同步重算；满每日时长按全天工资结算。")
        track.setAccessibilityLabel(L("今日已上班进度，拖动可手动补卡"))
        addSubview(track)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() {
        super.layout()
        let w = bounds.width, h = bounds.height
        let compact = w < 300 || h < 225
        for v in [rates, elapsed, remaining, quote, salary, stop, finish, reset, shuffle, settingsButton, calendarButton] { v.isHidden = compact }
        let baseFont: CGFloat = amount.stringValue.count > 12 ? 32 : amount.stringValue.count > 10 ? 38 : 46
        if compact {
            let pad: CGFloat = 10
            title.font = .systemFont(ofSize: 9)
            status.font = .systemFont(ofSize: 9)
            title.frame = NSRect(x: pad, y: 5, width: 55, height: 14)
            status.frame = NSRect(x: 65, y: 5, width: max(20, w-75), height: 14)
            let amountHeight = max(25, h-65)
            let fit = min((w-20) / max(1, (amount.stringValue as NSString).size(withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 46, weight: .medium)]).width), amountHeight/58)
            amount.font = .monospacedDigitSystemFont(ofSize: 46*fit, weight: .medium)
            amount.frame = NSRect(x: pad, y: 21, width: w-20, height: amountHeight)
            track.frame = NSRect(x: pad, y: h-42, width: w-20, height: 18)
            action.controlSize = .mini
            action.font = .systemFont(ofSize: 9)
            action.frame = NSRect(x: pad, y: h-24, width: w-20, height: 21)
            return
        }
        let scale = min(w/360, h/280)
        let ox = (w-360*scale)/2, oy = (h-280*scale)/2
        func rect(_ x: CGFloat,_ y: CGFloat,_ width: CGFloat,_ height: CGFloat) -> NSRect {
            NSRect(x: ox+x*scale,y: oy+y*scale,width: width*scale,height: height*scale)
        }
        for label in [title,status,rates,elapsed,remaining,quote] { label.font = .systemFont(ofSize: (AppLanguage.english ? 9:10)*scale) }
        for button in [salary,action,stop,finish,reset,shuffle,settingsButton,calendarButton] { button.controlSize = scale >= 1.5 ? .large : .small; button.font = .systemFont(ofSize: (AppLanguage.english ? 9:10)*scale) }
        amount.font = .monospacedDigitSystemFont(ofSize: baseFont*scale, weight: .medium)
        title.frame = rect(18,12,90,16)
        status.frame = rect(220,12,120,16)
        amount.frame = rect(16,34,328,62)
        rates.frame = rect(18,102,324,16)
        elapsed.frame = rect(18,131,146,16)
        remaining.frame = rect(196,131,146,16)
        track.frame = rect(18,148,324,18)
        quote.frame = rect(18,170,264,18)
        shuffle.frame = rect(284,169,60,20)
        salary.frame = rect(14,199,128,23)
        settingsButton.frame = rect(148,199,66,23)
        calendarButton.frame = rect(220,199,48,23)
        salary.alignment = .left
        reset.frame = rect(274,199,72,23)
        action.frame = rect(14,235,106,28)
        stop.frame = rect(127,235,106,28)
        finish.frame = rect(240,235,106,28)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var view: MeterView!
    var timer: Timer?
    var item: NSStatusItem!
    var state = WorkState()
    var floatingEnabled = true
    var wasRunningBeforeScrub = false
    var modeBeforeScrub = "idle"
    var settings = MeterSettings()
    var records: [String:PunchRecord] = [:]
    var activeID: String?
    var activeDate: Date?
    var calendarWindow: NSWindow?
    var calendarView: CalendarView?
    var monthTitle: NSTextField?
    var lastRecordSave = Date.distantPast
    func dayPay() -> Double { settings.dayPay(monthlySalary:state.salary) }
    func duration() -> Double { state.duration(limit: settings.limit) }
    func recordCurrent() {
        guard let id = activeID, let date = activeDate else { return }
        let seconds = duration()
        records[id] = PunchRecord(id:id,date:date,seconds:seconds,earnings:dayPay()*(state.fullDay ? 1 : seconds/settings.limit),mode:state.mode,fullDay:state.fullDay)
    }
    func beginRecordIfNeeded() {
        if activeID == nil { activeID=UUID().uuidString;activeDate=Date() }
    }
    func save() {
        recordCurrent()
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data,forKey:"meterSettings") }
        if let data = try? JSONEncoder().encode(records) { defaults.set(data,forKey:"punchRecords") }
        defaults.set(activeID,forKey:"activeID"); defaults.set(activeDate,forKey:"activeDate")
        lastRecordSave = Date()
        if let data = try? JSONEncoder().encode(state) { UserDefaults.standard.set(data, forKey: "workState") }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let data = UserDefaults.standard.data(forKey: "workState"), let decoded = try? JSONDecoder().decode(WorkState.self, from: data), decoded.salary.isFinite, decoded.salary >= 0, decoded.salary <= 1e9, decoded.elapsed.isFinite, decoded.elapsed >= 0 { state = decoded }
        let defaults = UserDefaults.standard
        if let data=defaults.data(forKey:"meterSettings"), let decoded=try? JSONDecoder().decode(MeterSettings.self,from:data), decoded.valid { settings=decoded }
        if let data=defaults.data(forKey:"punchRecords"), let decoded=try? JSONDecoder().decode([String:PunchRecord].self,from:data) { records=decoded }
        activeID=defaults.string(forKey:"activeID");activeDate=defaults.object(forKey:"activeDate") as? Date
        if state.mode != "idle" && (activeID == nil || activeDate == nil) {
            activeID=UUID().uuidString;activeDate=state.start.map{Date(timeIntervalSince1970:$0-state.elapsed)} ?? Date()
        }
        window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 360,height: 280), styleMask: [.titled,.closable,.miniaturizable,.resizable], backing: .buffered, defer: false)
        window.delegate = self
        window.contentMinSize = NSSize(width: 160, height: 100)
        window.title = L("上班鼓励器")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(srgbRed: 0.10, green: 0.13, blue: 0.085, alpha: 1)
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary]
        view = MeterView(frame: NSRect(x: 0, y: 0, width: 360, height: 280))
        window.contentView = view
        view.track.target=self;view.track.action = #selector(adjustProgress)
        view.track.onBegin = { [weak self] in self?.wasRunningBeforeScrub = self?.state.mode == "running";self?.modeBeforeScrub=self?.state.mode ?? "idle" }
        view.track.onEnd = { [weak self] in self?.save();self?.refresh() }
        view.action.target = self; view.action.action = #selector(toggle)
        view.stop.target = self; view.stop.action = #selector(stop)
        view.finish.target = self; view.finish.action = #selector(finish)
        view.reset.target = self; view.reset.action = #selector(reset)
        view.salary.target = self; view.salary.action = #selector(editSalary)
        view.settingsButton.target=self;view.settingsButton.action = #selector(editSettings)
        view.calendarButton.target=self;view.calendarButton.action = #selector(showCalendar)
        view.shuffle.target = self; view.shuffle.action = #selector(shuffle)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "¥"
        let menu = NSMenu()
        menu.addItem(withTitle: L("显示鼓励器"), action: #selector(show), keyEquivalent: "")
        menu.addItem(withTitle: L("恢复默认大小"), action: #selector(defaultSize), keyEquivalent: "")
        menu.addItem(withTitle: L("迷你模式"), action: #selector(miniSize), keyEquivalent: "")
        menu.addItem(withTitle: L("铺满桌面"), action: #selector(fillDesktop), keyEquivalent: "")
        menu.addItem(withTitle: L("进入 / 退出全屏"), action: #selector(fullScreen), keyEquivalent: "")
        menu.addItem(withTitle: L("回到右下角"), action: #selector(bottomRight), keyEquivalent: "")
        let floating = menu.addItem(withTitle: L("窗口置顶"), action: #selector(toggleFloating(_:)), keyEquivalent: "")
        floating.state = .on
        menu.addItem(.separator())
        menu.addItem(withTitle: L("开始 / 暂停 / 继续"), action: #selector(toggle), keyEquivalent: "")
        menu.addItem(withTitle: L("停止计时"), action: #selector(stop), keyEquivalent: "")
        menu.addItem(withTitle: L("下班"), action: #selector(finish), keyEquivalent: "")
        menu.addItem(withTitle: L("关于上班鼓励器"), action:#selector(showAbout),keyEquivalent:"")
        menu.addItem(withTitle: "中文 / English", action:#selector(editSettings),keyEquivalent:"")
        menu.addItem(withTitle: L("修改工资"), action: #selector(editSettings), keyEquivalent: "")
        menu.addItem(withTitle: L("上班记录"), action: #selector(showCalendar), keyEquivalent: "")
        menu.addItem(withTitle: L("修改薪资"), action: #selector(editSalary), keyEquivalent: "")
        menu.addItem(withTitle: L("重新开始"), action: #selector(reset), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: L("退出（保留计时状态）"), action: #selector(quit), keyEquivalent: "q")
        for entry in menu.items { entry.target = self }
        item.menu = menu
        bottomRight()
        show()
        refresh()
        timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in guard let self=self,!self.view.track.isScrubbing else {return};self.refresh() }
        RunLoop.main.add(timer!, forMode: .common)
    }
    @objc func show() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func bottomRight() {
        let screen = window.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let f = screen.visibleFrame
        window.setFrameOrigin(NSPoint(x: f.maxX-window.frame.width-18, y: f.minY+18))
    }
    @objc func toggleFloating(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
        floatingEnabled = sender.state == .on
        if !window.styleMask.contains(.fullScreen) { window.level = floatingEnabled ? .floating : .normal }
    }
    func windowWillUseStandardFrame(_ window: NSWindow, defaultFrame newFrame: NSRect) -> NSRect {
        (window.screen ?? NSScreen.main)!.visibleFrame
    }
    func windowWillEnterFullScreen(_ notification: Notification) { window.level = .normal }
    func windowDidExitFullScreen(_ notification: Notification) { window.level = floatingEnabled ? .floating : .normal }
    func windowDidResize(_ notification: Notification) { view.needsLayout = true }
    @objc func defaultSize() { setSize(NSSize(width: 360,height: 280)) }
    @objc func miniSize() { setSize(NSSize(width: 160,height: 100)) }
    func setSize(_ size: NSSize) {
        guard !window.styleMask.contains(.fullScreen) else { return }
        let top = window.frame.maxY
        let f = window.frameRect(forContentRect: NSRect(origin: .zero,size: size))
        window.setFrame(NSRect(x: window.frame.minX,y: top-f.height,width: f.width,height: f.height), display: true)
        bottomRight(); show()
    }
    @objc func fillDesktop() {
        guard !window.styleMask.contains(.fullScreen) else { return }
        window.setFrame((window.screen ?? NSScreen.main)!.visibleFrame, display: true); show()
    }
    @objc func fullScreen() { show(); window.toggleFullScreen(nil) }
    @objc func quit() { save(); NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { show(); return true }
    func applicationWillTerminate(_ notification: Notification) { save() }
    func refresh() {
        let duration = self.duration()
        if state.mode == "running" && duration >= settings.limit {
            state.elapsed = settings.limit; state.start = nil; state.mode = "done"; state.fullDay = true; save()
        }
        let day = dayPay()
        let earnings = state.fullDay ? day : day*duration/settings.limit
        view.title.toolTip=L("按你填写的工资和工时估算；数据只保存在本机。仅供娱乐，不可商用。")
        view.amount.stringValue = String(format: "¥%.3f", earnings)
        view.rates.stringValue = String(format: L("每秒 ¥%.4f    时薪 ¥%.2f    日薪 ¥%.2f"), day/settings.limit, day/settings.dailyHours, day)
        view.elapsed.stringValue = String(format:L("今日已上班 %.2f 小时"),duration/3600)
        view.elapsed.toolTip = L("今日已上班 ") + clock(duration) + L("，拖动进度条可补卡")
        view.track.isEnabled = dayPay()>0
        view.remaining.stringValue = L("距下班 ") + clock(state.fullDay ? 0 : settings.limit-duration)
        view.progress = state.fullDay ? 1 : duration/settings.limit
        view.status.stringValue = ["idle":L("● 准备上班"),"running":L("● 正在赚钱"),"paused":L("● 已暂停"),"stopped":L("● 计时已结束"),"done":L("● 已下班")][state.mode] ?? ""
        view.salary.title = dayPay() > 0 ? String(format: settings.isDaily ? L("日薪 ¥%.2f"):L("月薪 ¥%.0f"), settings.isDaily ? dayPay():state.salary) : L("输入工资 →")
        view.action.title = ["idle":L("开始上班"),"running":L("暂停"),"paused":L("继续"),"stopped":L("已停止"),"done":L("已下班")][state.mode] ?? L("开始上班")
        view.action.isEnabled = ["idle","running","paused"].contains(state.mode)
        view.stop.isEnabled = ["running","paused"].contains(state.mode)
        view.finish.isEnabled = dayPay() > 0 && state.mode != "done"
        view.finish.toolTip = L("按一天工资记录估算收入，实际计时时长仍会保留。")
        view.stop.toolTip = L("结束本次计时，保留已经累计的估算收入。")
        view.salary.toolTip = L("随时修改薪资制度和参数，当前记录按新设置重新估算")
        recordCurrent()
        if Date().timeIntervalSince(lastRecordSave) >= 15 { save() }
        if calendarWindow?.isVisible == true { updateCalendar() }
        view.needsLayout = true
    }
    @objc func adjustProgress() {
        guard dayPay()>0 else {return}
        let raw=view.track.doubleValue*settings.limit
        let seconds=min(settings.limit,max(0,(raw/60).rounded()*60))
        if let date=activeDate,!sameDay(date,Date()) {
            if state.mode=="running" || state.mode=="paused" {state.elapsed=duration();state.start=nil;state.mode="stopped"}
            save();activeID=nil;activeDate=nil;state=WorkState(salary:state.salary)
        }
        beginRecordIfNeeded()
        state.setWorkedTime(seconds,limit:settings.limit,keepRunning:wasRunningBeforeScrub)
        if modeBeforeScrub=="stopped" && !state.fullDay {state.mode="stopped"}
        refresh()
        if !view.track.isScrubbing {save()}
    }
    @objc func toggle() {
        refresh()
        if state.mode == "idle" {
            if dayPay() <= 0 { editSettings(); if dayPay() <= 0 { return } }
            beginRecordIfNeeded();state.elapsed = 0; state.start = Date().timeIntervalSince1970; state.fullDay = false; state.mode = "running"
        } else if state.mode == "running" {
            state.elapsed = duration(); state.start = nil; state.mode = "paused"
        } else if state.mode == "paused" { state.start = Date().timeIntervalSince1970; state.mode = "running" }
        save(); refresh()
    }
    @objc func stop() {
        refresh()
        guard ["running","paused"].contains(state.mode) else { return }
        state.elapsed = duration(); state.start = nil; state.mode = "stopped"; save(); refresh()
    }
    @objc func finish() {
        guard dayPay() > 0 else { return }
        beginRecordIfNeeded();state.elapsed = duration(); state.start = nil; state.mode = "done"; state.fullDay = true; save(); refresh()
    }
    @objc func reset() {
        if duration() > 0 || state.fullDay {
            let alert = NSAlert(); alert.messageText = L("要重新开始吗？"); alert.informativeText = L("这次记录会留在日历里。重新开始后，计时从零算，工资不用再填。"); alert.addButton(withTitle: L("重新开始")); alert.addButton(withTitle: L("取消"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        if state.mode == "running" || state.mode == "paused" { state.elapsed=duration();state.start=nil;state.mode="stopped" }
        save();activeID=nil;activeDate=nil
        state = WorkState(salary: state.salary); save(); refresh()
    }
    @objc func showAbout() {
        let alert=NSAlert();alert.window.appearance=NSAppearance(named:.darkAqua)
        alert.messageText=L("上班鼓励器")
        alert.informativeText=L("忍忍，别和钱过不去。\n\n输入工资，点「开始上班」，桌面上就会多一个小窗口，显示今天已经赚了多少钱。\n\n不想上班的时候，看两眼。\n\n累了可以暂停，忘记开计时可以拖进度条补上。点「下班」，按一天工资记。之前的记录在「上班记录」里。\n\n金额是估算的。工资和记录只存在自己电脑上。\n\n仅供娱乐，不可商用。")
        alert.addButton(withTitle:L("知道了"));alert.runModal()
    }
    @objc func editSalary() { editSettings() }
    @objc func editSettings() {
        let alert=NSAlert();alert.messageText=L("修改工资");alert.window.appearance=NSAppearance(named:.darkAqua)
        alert.informativeText=L("改完后，这次上班的金额会重新计算，以前的记录不变。")
        let form=PaySettingsForm(salary:state.salary,settings:settings)
        alert.accessoryView=form;alert.addButton(withTitle:L("保存"));alert.addButton(withTitle:L("取消"));alert.window.initialFirstResponder=form.pay
        while alert.runModal() == .alertFirstButtonReturn {
            form.capturePay()
            func number(_ s:String)->Double { Double(s.replacingOccurrences(of:",",with:"").trimmingCharacters(in:.whitespacesAndNewlines)) ?? 0 }
            let payValue=number(form.pay.stringValue)
            let h=number(form.hours.stringValue)
            let d=form.isDaily ? settings.workDays : form.daysChoice.indexOfSelectedItem==0 ? 22 : number(form.days.stringValue)
            let candidate=MeterSettings(dailyHours:h,workDays:d,customDays:form.isDaily ? settings.customDays:form.daysChoice.indexOfSelectedItem==1,payMode:form.isDaily ? "daily":"monthly",dailyPay:form.isDaily ? payValue:settings.dailyPay)
            guard payValue.isFinite && payValue>0 && payValue<=1e9 && candidate.valid else { alert.informativeText=L("薪资须大于 0 且不超过 10 亿；每日时长须大于 0 且不超过 24 小时；月薪制工作日须为 1—31 天。");continue }
            refresh()
            if state.mode == "running" { state.elapsed=duration();state.start=Date().timeIntervalSince1970 }
            settings=candidate
            if !form.isDaily {state.salary=payValue}
            UserDefaults.standard.set(form.languageChoice.indexOfSelectedItem==1 ? "en":"zh-Hans",forKey:"appLanguage")
            applyLanguage();save();refresh();return
        }
    }
    func applyLanguage() {
        func update(_ root:NSView) {
            if let label=root as? NSTextField {label.stringValue=AppLanguage.translateExisting(label.stringValue)}
            if let button=root as? NSButton {button.title=AppLanguage.translateExisting(button.title)}
            if let tip=root.toolTip {root.toolTip=AppLanguage.translateExisting(tip)}
            for child in root.subviews {update(child)}
        }
        update(view)
        if let root=calendarWindow?.contentView {update(root)}
        for entry in item.menu?.items ?? [] {entry.title=AppLanguage.translateExisting(entry.title)}
        window.title=L("上班鼓励器");calendarWindow?.title=L("上班记录");updateCalendar()
    }
    @objc func showCalendar() {
        if calendarWindow == nil {
            let w=NSWindow(contentRect:NSRect(x:0,y:0,width:580,height:655),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
            w.title=L("上班记录");w.isReleasedWhenClosed=false;w.appearance=NSAppearance(named:.darkAqua);w.level = .floating
            let root=NSView(frame:NSRect(x:0,y:0,width:580,height:655));w.contentView=root
            let title=NSTextField(labelWithString:"");title.alignment = .center;title.font = .systemFont(ofSize:17,weight:.medium);title.frame=NSRect(x:170,y:615,width:240,height:25);root.addSubview(title);monthTitle=title
            for (text,x,selector) in [(L("‹ 上月"),CGFloat(20),#selector(previousMonth)),(L("本月"),CGFloat(425),#selector(currentMonth)),(L("下月 ›"),CGFloat(490),#selector(nextMonth))] {
                let button=NSButton(title:text,target:self,action:selector);button.frame=NSRect(x:x,y:611,width:70,height:30);root.addSubview(button)
            }
            let cv=CalendarView(frame:NSRect(x:0,y:0,width:580,height:605));root.addSubview(cv);calendarView=cv;calendarWindow=w;w.center()
        }
        recordCurrent();updateCalendar();calendarWindow?.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
    func updateCalendar() {
        calendarView?.records=Array(records.values);calendarView?.needsDisplay=true
        if let month=calendarView?.month { monthTitle?.stringValue=dateText(month,L("yyyy年 M月")) }
    }
    @objc func previousMonth() { shiftMonth(-1) }
    @objc func nextMonth() { shiftMonth(1) }
    @objc func currentMonth() { calendarView?.month=Calendar.current.date(from:Calendar.current.dateComponents([.year,.month],from:Date()))!;calendarView?.selected=Date();updateCalendar() }
    func shiftMonth(_ offset:Int) { if let cv=calendarView { cv.month=Calendar.current.date(byAdding:.month,value:offset,to:cv.month)!;cv.selected=cv.month;updateCalendar() } }
    @objc func shuffle() {
        view.quote.stringValue = lines.filter { $0 != view.quote.stringValue }.randomElement()!
    }
}

if CommandLine.arguments.contains("--self-test") {
    AppLanguage.override=CommandLine.arguments.contains("--english") ? "en":"zh-Hans"
    precondition(!AppLanguage.translations.isEmpty)
    precondition(L("上班鼓励器") == (AppLanguage.english ? "Work Cheer":"上班鼓励器"))
    let running = WorkState(salary: 21750, elapsed: 3600, start: 1000, mode: "running")
    precondition(running.duration(4600) == 7200)
    precondition(running.duration(100000) == 28800)
    let paused = WorkState(salary: 21750, elapsed: 3600, mode: "paused")
    precondition(paused.duration(100000) == 3600)
    precondition(paused.salary / 21.75 * paused.duration() / 28800 == 125)
    let encoded = try! JSONEncoder().encode(running)
    let restored = try! JSONDecoder().decode(WorkState.self, from: encoded)
    precondition(restored.duration(4600) == 7200)
    precondition(lines.count == 20)
    _ = NSApplication.shared
    for size in [NSSize(width:160,height:100), NSSize(width:360,height:280), NSSize(width:1200,height:750), NSSize(width:160,height:700), NSSize(width:1200,height:100)] {
        let meter = MeterView(frame: NSRect(origin: .zero, size: size))
        meter.amount.stringValue = "¥12345678.123"
        meter.layout()
        for child in meter.subviews where !child.isHidden {
            precondition(child.frame.minX >= -1 && child.frame.minY >= -1 && child.frame.maxX <= size.width+1 && child.frame.maxY <= size.height+1, "Control exceeds window")
        }
    }
    precondition(MeterSettings().workDays == 22)
    precondition(!MeterSettings(dailyHours:0).valid)
    precondition(!MeterSettings(workDays:32).valid)
    precondition(MeterSettings(dailyHours:7.5,workDays:20,customDays:true).valid)
    precondition(running.duration(100000,limit:21600) == 21600)
    let model = AppDelegate()
    model.settings=MeterSettings(dailyHours:6,workDays:22)
    model.state=WorkState(salary:22000,elapsed:10800,mode:"paused")
    model.activeID="one";model.activeDate=Date();model.recordCurrent()
    precondition(model.records["one"]!.earnings == 500)
    model.activeID="two";model.state.fullDay=true;model.recordCurrent()
    precondition(model.records["two"]!.earnings == 1000)
    model.state.salary=44000;model.recordCurrent()
    precondition(model.records["two"]!.earnings == 2000 && model.records["one"]!.earnings == 500)
    let history=try! JSONDecoder().decode([String:PunchRecord].self,from:JSONEncoder().encode(model.records))
    precondition(history.count == 2 && history["one"]!.seconds == 10800)
    let legacy=Data("{\"salary\":22000,\"elapsed\":3600,\"mode\":\"paused\",\"fullDay\":false}".utf8)
    precondition((try! JSONDecoder().decode(WorkState.self,from:legacy)).elapsed == 3600)
    let oldSettings=Data("{\"dailyHours\":7.5,\"workDays\":22,\"customDays\":false}".utf8)
    let migrated=try! JSONDecoder().decode(MeterSettings.self,from:oldSettings)
    precondition(!migrated.isDaily && migrated.dayPay(monthlySalary:22000)==1000)
    model.settings=MeterSettings(dailyHours:5,workDays:22,payMode:"daily",dailyPay:500)
    model.state=WorkState(salary:0,elapsed:9000,mode:"paused")
    model.activeID="daily";model.recordCurrent()
    precondition(model.records["daily"]!.earnings==250 && model.dayPay()==500)
    model.state.fullDay=true;model.recordCurrent();precondition(model.records["daily"]!.earnings==500)
    precondition(model.records["one"]!.earnings==500)
    let savedSettings=try! JSONDecoder().decode(MeterSettings.self,from:JSONEncoder().encode(model.settings))
    precondition(savedSettings.isDaily && savedSettings.dailyPay==500)
    let form=PaySettingsForm(salary:22000,settings:MeterSettings())
    form.pay.stringValue="33000";form.mode.selectItem(at:1);form.changePayMode()
    precondition(form.days.isHidden && form.payLabel.stringValue==L("日薪（元）"))
    form.pay.stringValue="700";form.mode.selectItem(at:0);form.changePayMode()
    precondition(form.pay.stringValue=="33000" && !form.days.isHidden)
    form.mode.selectItem(at:1);form.changePayMode();precondition(form.pay.stringValue=="700")
    var punched=WorkState(salary:22000)
    punched.setWorkedTime(10800,limit:28800,keepRunning:false,now:1000)
    precondition(punched.mode=="paused" && punched.duration(5000)==10800)
    punched.setWorkedTime(14400,limit:28800,keepRunning:true,now:1000)
    precondition(punched.duration(4600)==18000)
    punched.setWorkedTime(40000,limit:28800,keepRunning:true)
    precondition(punched.fullDay && punched.mode=="done" && punched.elapsed==28800)
    punched.setWorkedTime(7200,limit:28800,keepRunning:false)
    precondition(!punched.fullDay && punched.mode=="paused" && punched.elapsed==7200)
    punched.mode="stopped";punched.setWorkedTime(3600,limit:28800,keepRunning:false)
    precondition(punched.mode=="stopped")
    model.state=punched;model.activeID="punch";model.recordCurrent()
    precondition(model.records["punch"]!.seconds==3600 && model.records["punch"]!.earnings==100)
    print("Passed: manual punch, pause/resume, full-day/reverse adjustment, calendar recording, pay modes and resizing")
} else if CommandLine.arguments.contains("--settings-preview") {
    _ = NSApplication.shared
    if CommandLine.arguments.contains("--english") {AppLanguage.override="en"}
    let form=PaySettingsForm(salary:22000,settings:MeterSettings(dailyHours:8,payMode:CommandLine.arguments.contains("--daily") ? "daily":"monthly",dailyPay:800))
    form.appearance=NSAppearance(named:.darkAqua);form.wantsLayer=true;form.layer?.backgroundColor=NSColor(srgbRed:0.16,green:0.17,blue:0.15,alpha:1).cgColor
    if let rep=form.bitmapImageRepForCachingDisplay(in:form.bounds) {
        form.cacheDisplay(in:form.bounds,to:rep)
        try! rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments.last!))
    }
} else if CommandLine.arguments.contains("--calendar-preview") {
    _ = NSApplication.shared
    if CommandLine.arguments.contains("--english") {AppLanguage.override="en"}
    let cv=CalendarView(frame:NSRect(x:0,y:0,width:580,height:605))
    let cal=Calendar.current
    cv.selected=cal.date(byAdding:.day,value:3,to:cv.month)!
    for day in [1,2,4] {
        cv.records.append(PunchRecord(id:String(day),date:cal.date(byAdding:.day,value:day-1,to:cv.month)!,seconds:day==4 ? 10800:28800,earnings:day==4 ? 375:1000,mode:day==4 ? "paused":"done",fullDay:day != 4))
    }
    if let rep=cv.bitmapImageRepForCachingDisplay(in:cv.bounds) {
        cv.cacheDisplay(in:cv.bounds,to:rep)
        try! rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments.last!))
    }
} else if CommandLine.arguments.contains("--preview") {
    _ = NSApplication.shared
    if CommandLine.arguments.contains("--english") {AppLanguage.override="en"}
    let width = CommandLine.arguments.contains("--mini") ? 160.0 : CommandLine.arguments.contains("--large") ? 1200.0 : 360.0
    let height = CommandLine.arguments.contains("--mini") ? 100.0 : CommandLine.arguments.contains("--large") ? 750.0 : 280.0
    let meter = MeterView(frame: NSRect(x: 0, y: 0, width: width, height: height))
    meter.amount.stringValue = "¥288.958"
    meter.status.stringValue = L("● 正在赚钱")
    meter.rates.stringValue = L("每秒 ¥0.0136    时薪 ¥49.04    日薪 ¥392.32")
    meter.elapsed.stringValue = L("今日已上班 5.89 小时")
    meter.remaining.stringValue = L("距下班 02:06:29")
    meter.salary.title = L("月薪 ¥8,533 · 修改")
    meter.quote.stringValue = L("忍忍，别和钱过不去。")
    meter.action.title = L("暂停")
    meter.progress = 0.737
    meter.layout()
    if let rep = meter.bitmapImageRepForCachingDisplay(in: meter.bounds) {
        meter.cacheDisplay(in: meter.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            try! png.write(to: URL(fileURLWithPath: CommandLine.arguments.last!))
        }
    }
} else {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
