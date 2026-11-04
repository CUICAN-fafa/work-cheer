import Cocoa

enum AppLanguage {
    static var override: String?
    static var code: String { override ?? UserDefaults.standard.string(forKey:"appLanguage") ?? "zh-Hans" }
    static var english: Bool { code == "en" }
    static let translations: [String:String] = {
        let bundled=Bundle.main.url(forResource:"en",withExtension:"json")
        let source=URL(fileURLWithPath:"en.json")
        guard let data=try? Data(contentsOf:bundled ?? source),let result=try? JSONDecoder().decode([String:String].self,from:data) else {return [:]}
        return result
    }()
    static func translateExisting(_ value:String)->String {
        let source=translations.first(where:{$0.value==value})?.key ?? value
        return L(source)
    }
}
func L(_ source:String)->String { AppLanguage.english ? AppLanguage.translations[source] ?? source:source }
