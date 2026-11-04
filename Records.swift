import Cocoa

struct MeterSettings: Codable {
    var dailyHours: Double = 8
    var workDays: Double = 22
    var customDays: Bool = false
    var payMode: String? = nil
    var dailyPay: Double? = nil
    var isDaily: Bool { payMode == "daily" }
    func dayPay(monthlySalary: Double) -> Double { isDaily ? (dailyPay ?? 0) : monthlySalary/workDays }
    var limit: Double { dailyHours * 3600 }
    var valid: Bool { (payMode == nil || payMode == "monthly" || payMode == "daily") && (!isDaily || ((dailyPay ?? 0).isFinite && (dailyPay ?? 0)>0 && (dailyPay ?? 0)<=1e9)) && dailyHours.isFinite && dailyHours > 0 && dailyHours <= 24 && workDays.isFinite && workDays >= 1 && workDays <= 31 }
}
struct PunchRecord: Codable {
    var id: String
    var date: Date
    var seconds: Double
    var earnings: Double
    var mode: String
    var fullDay: Bool
}
func sameDay(_ a: Date, _ b: Date) -> Bool { Calendar.current.isDate(a, inSameDayAs: b) }
func dateText(_ date: Date, _ format: String) -> String {
    let f = DateFormatter(); f.locale = Locale(identifier: AppLanguage.english ? "en_US":"zh_CN"); f.dateFormat = format; return f.string(from: date)
}
final class CalendarView: NSView {
    override var isFlipped: Bool { true }
    var month = Calendar.current.date(from: Calendar.current.dateComponents([.year,.month], from: Date()))!
    var selected = Date()
    var records: [PunchRecord] = []
    var dayRects: [(NSRect, Date)] = []
    var didSelect: (() -> Void)?
    override init(frame: NSRect) { super.init(frame: frame); appearance = NSAppearance(named: .darkAqua); wantsLayer = true; layer?.backgroundColor = NSColor(srgbRed:0.10,green:0.13,blue:0.085,alpha:1).cgColor }
    required init?(coder: NSCoder) { fatalError() }
    func text(_ s: String, _ rect: NSRect, _ size: CGFloat, _ color: NSColor = muted, _ bold: Bool = false) {
        (s as NSString).draw(in: rect, withAttributes: [.font:NSFont.systemFont(ofSize:size,weight:bold ? .medium : .regular),.foregroundColor:color])
    }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        dayRects = []
        let cal = Calendar.current
        let monthly = records.filter { cal.isDate($0.date, equalTo:month,toGranularity:.month) }
        let days = Set(monthly.map { cal.component(.day,from:$0.date) }).count
        text(String(format:L("已打卡 %d 天   ·   记录收入 ¥%.2f"),days,monthly.reduce(0){$0+$1.earnings}),NSRect(x:20,y:12,width:500,height:24),13,green)
        let width = (bounds.width-40)/7
        for (i,name) in [L("一"),L("二"),L("三"),L("四"),L("五"),L("六"),L("日")].enumerated() { text(name,NSRect(x:28+CGFloat(i)*width,y:50,width:width-8,height:20),12) }
        let offset = (cal.component(.weekday,from:month)+5)%7
        let count = cal.range(of:.day,in:.month,for:month)!.count
        for day in 1...count {
            let date = cal.date(byAdding:.day,value:day-1,to:month)!
            let index = day-1+offset
            let rect = NSRect(x:20+CGFloat(index%7)*width,y:80+CGFloat(index/7)*65,width:width-5,height:60)
            dayRects.append((rect,date))
            let daily = records.filter { sameDay($0.date,date) }
            if sameDay(date,selected) { green.withAlphaComponent(0.13).setFill(); NSBezierPath(roundedRect:rect,xRadius:8,yRadius:8).fill() }
            if sameDay(date,Date()) { green.setStroke(); let p=NSBezierPath(roundedRect:rect.insetBy(dx:1,dy:1),xRadius:8,yRadius:8); p.lineWidth=1;p.stroke() }
            text(String(day),NSRect(x:rect.minX+7,y:rect.minY+5,width:width-15,height:17),12,daily.isEmpty ? muted : .white)
            if !daily.isEmpty {
                text(String(format:"¥%.2f",daily.reduce(0){$0+$1.earnings}),NSRect(x:rect.minX+7,y:rect.minY+24,width:width-15,height:15),10,green)
                let label = daily.contains{$0.mode=="running"} ? L("计费中") : daily.contains{$0.mode=="paused"} ? L("暂停中") : daily.contains{$0.fullDay} ? L("已下班") : L("已停止")
                text(label,NSRect(x:rect.minX+7,y:rect.minY+41,width:width-15,height:14),9)
            }
        }
        let daily = records.filter { sameDay($0.date,selected) }
        let y: CGFloat = 485
        text(dateText(selected,L("M月d日")) + (daily.isEmpty ? L(" · 暂无打卡记录") : String(format:L(" · %d 次打卡"),daily.count)),NSRect(x:20,y:y,width:500,height:22),13,.white,true)
        if !daily.isEmpty {
            text(String(format:L("计时时长 %@    收入 ¥%.2f"),clock(daily.reduce(0){$0+$1.seconds}),daily.reduce(0){$0+$1.earnings}),NSRect(x:20,y:y+28,width:520,height:22),12,green)
            text(daily.contains{$0.fullDay} ? L("含全天工资结算；计时时长保留实际记录。") : L("按实际计时时长估算，暂停期间不计费。"),NSRect(x:20,y:y+55,width:520,height:20),11)
        }
        text(L("记录保存在本机；跨午夜的打卡归入开始日期。"),NSRect(x:20,y:575,width:520,height:20),10)
    }
    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow,from:nil)
        if let match = dayRects.first(where:{$0.0.contains(p)}) { selected=match.1;needsDisplay=true;didSelect?() }
    }
}

final class PaySettingsForm: NSView {
    let languageChoice = NSPopUpButton(frame:NSRect(x:144,y:294,width:178,height:26))
    let mode = NSPopUpButton(frame: NSRect(x:144,y:250,width:178,height:26))
    let payLabel = NSTextField(labelWithString: L("月薪（元）"))
    let pay = NSTextField(frame: NSRect(x:144,y:206,width:170,height:26))
    let hours = NSTextField(frame: NSRect(x:144,y:162,width:170,height:26))
    let daysChoice = NSPopUpButton(frame:NSRect(x:140,y:118,width:178,height:26))
    let days = NSTextField(frame:NSRect(x:144,y:74,width:170,height:26))
    let daysLabel = NSTextField(labelWithString:L("每月工作日"))
    let customLabel = NSTextField(labelWithString:L("手动工作日（1—31）"))
    let note = NSTextField(wrappingLabelWithString:"")
    var monthlyPay: String
    var dailyPay: String
    var lastDaily: Bool
    var isDaily: Bool { mode.indexOfSelectedItem == 1 }
    init(salary:Double, settings:MeterSettings) {
        monthlyPay=salary>0 ? String(format:"%.2f",salary):""
        dailyPay=(settings.dailyPay ?? 0)>0 ? String(format:"%.2f",settings.dailyPay!):""
        lastDaily=settings.isDaily
        super.init(frame:NSRect(x:0,y:0,width:340,height:334))
        appearance=NSAppearance(named:.darkAqua)
        func label(_ text:String,_ y:CGFloat) { let l=NSTextField(labelWithString:text);l.frame=NSRect(x:0,y:y,width:138,height:24);l.font = .systemFont(ofSize:12);addSubview(l) }
        label(L("界面语言"),294);languageChoice.addItems(withTitles:["简体中文","English"]);languageChoice.selectItem(at:AppLanguage.english ? 1:0);addSubview(languageChoice)
        label(L("薪资制度"),250);addSubview(mode);mode.addItems(withTitles:[L("月薪制"),L("日薪制")]);mode.selectItem(at:settings.isDaily ? 1:0)
        payLabel.frame=NSRect(x:0,y:206,width:138,height:24);payLabel.font = .systemFont(ofSize:12);addSubview(payLabel);addSubview(pay)
        label(L("每日工作时长（小时）"),162);hours.stringValue=String(format:"%g",settings.dailyHours);addSubview(hours)
        daysLabel.frame=NSRect(x:0,y:118,width:138,height:24);daysLabel.font = .systemFont(ofSize:12);addSubview(daysLabel)
        addSubview(daysChoice);daysChoice.addItems(withTitles:[L("常规 · 22 天"),L("手动输入")]);daysChoice.selectItem(at:settings.customDays ? 1:0)
        customLabel.frame=NSRect(x:0,y:74,width:138,height:24);customLabel.font = .systemFont(ofSize:12);addSubview(customLabel);days.stringValue=String(format:"%g",settings.workDays);addSubview(days)
        note.frame=NSRect(x:0,y:12,width:330,height:45);note.font = .systemFont(ofSize:11);note.textColor = .secondaryLabelColor;addSubview(note)
        mode.target=self;mode.action = #selector(changePayMode)
        daysChoice.target=self;daysChoice.action = #selector(updateDays)
        updatePresentation()
    }
    required init?(coder:NSCoder) { fatalError() }
    func capturePay() { if lastDaily {dailyPay=pay.stringValue} else {monthlyPay=pay.stringValue} }
    @objc func changePayMode() { capturePay();lastDaily=isDaily;updatePresentation() }
    @objc func updateDays() { days.isEnabled = !isDaily && daysChoice.indexOfSelectedItem==1;customLabel.textColor = days.isEnabled ? .labelColor:.secondaryLabelColor }
    func updatePresentation() {
        payLabel.stringValue=isDaily ? L("单日工资（元）"):L("月薪（元）")
        pay.stringValue=isDaily ? dailyPay:monthlyPay
        for v in [daysLabel,daysChoice,customLabel,days] {v.isHidden=isDaily}
        note.frame.origin.y = isDaily ? 90:12
        note.stringValue=isDaily ? L("日薪 ÷ 每日小时数 = 时薪。\n手动下班按填写的单日工资结算。"):L("月薪 ÷ 每月工作日 = 日薪；日薪 ÷ 每日小时数 = 时薪。")
        updateDays()
    }
}

final class PunchSlider: NSSlider {
    var onBegin: (() -> Void)?
    var onEnd: (() -> Void)?
    var isScrubbing = false
    override var mouseDownCanMoveWindow: Bool { false }
    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isScrubbing=true;onBegin?()
        super.mouseDown(with:event)
        isScrubbing=false;onEnd?()
    }
    override func keyDown(with event: NSEvent) {
        guard isEnabled else { return }
        isScrubbing=true;onBegin?()
        super.keyDown(with:event)
        isScrubbing=false;onEnd?()
    }
}

final class GreenSliderCell: NSSliderCell {
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        let r=NSRect(x:rect.minX,y:rect.midY-2,width:rect.width,height:4)
        NSColor.white.withAlphaComponent(0.15).setFill()
        NSBezierPath(roundedRect:r,xRadius:2,yRadius:2).fill()
        let fraction=max(0,min(1,(doubleValue-minValue)/max(0.001,maxValue-minValue)))
        green.setFill()
        NSBezierPath(roundedRect:NSRect(x:r.minX,y:r.minY,width:r.width*fraction,height:4),xRadius:2,yRadius:2).fill()
    }
}
