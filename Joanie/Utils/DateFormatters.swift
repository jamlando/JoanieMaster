import Foundation

// MARK: - Date Formatters

extension DateFormatter {
    // MARK: - Static Formatters
    
    static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    static let displayDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let iso8601Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
    
    static let timelineDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
    
    static let memberSinceFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    static let birthdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()
    
    static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()
    
    static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }()
    
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()
    
    static let shortWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()
}

// MARK: - Date Extensions

extension Date {
    // MARK: - Computed Properties
    
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }
    
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
    
    var endOfWeek: Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.weekOfYear = 1
        components.second = -1
        return calendar.date(byAdding: components, to: startOfWeek) ?? self
    }
    
    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }
    
    var endOfMonth: Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return calendar.date(byAdding: components, to: startOfMonth) ?? self
    }
    
    var startOfYear: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: self)
        return calendar.date(from: components) ?? self
    }
    
    var endOfYear: Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 1
        components.second = -1
        return calendar.date(byAdding: components, to: startOfYear) ?? self
    }
    
    // MARK: - Helper Methods
    
    func isToday() -> Bool {
        return Calendar.current.isDateInToday(self)
    }
    
    func isYesterday() -> Bool {
        return Calendar.current.isDateInYesterday(self)
    }
    
    func isTomorrow() -> Bool {
        return Calendar.current.isDateInTomorrow(self)
    }
    
    func isThisWeek() -> Bool {
        return Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    func isThisMonth() -> Bool {
        return Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }
    
    func isThisYear() -> Bool {
        return Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year)
    }
    
    func daysSince(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: date, to: self)
        return components.day ?? 0
    }
    
    func daysUntil(_ date: Date) -> Int {
        return date.daysSince(self)
    }
    
    func yearsSince(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: date, to: self)
        return components.year ?? 0
    }
    
    func yearsUntil(_ date: Date) -> Int {
        return date.yearsSince(self)
    }
    
    // MARK: - Formatting Methods
    
    func formatted(style: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    func formatted(dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: self)
    }
    
    func formatted(format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
    
    func relativeFormatted() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    func shortRelativeFormatted() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    func abbreviatedRelativeFormatted() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Date Range

struct DateRangeStruct {
    let start: Date
    let end: Date
    
    var duration: TimeInterval {
        return end.timeIntervalSince(start)
    }
    
    var days: Int {
        return Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
    }
    
    var contains: (Date) -> Bool {
        return { date in
            return date >= self.start && date <= self.end
        }
    }
    
    var isToday: Bool {
        return start.isToday() && end.isToday()
    }
    
    var isThisWeek: Bool {
        return start.isThisWeek() && end.isThisWeek()
    }
    
    var isThisMonth: Bool {
        return start.isThisMonth() && end.isThisMonth()
    }
    
    var isThisYear: Bool {
        return start.isThisYear() && end.isThisYear()
    }
}

// MARK: - Date Range Extensions

extension DateRangeStruct {
    static func today() -> DateRangeStruct {
        return DateRangeStruct(start: Date().startOfDay, end: Date().endOfDay)
    }
    
    static func yesterday() -> DateRangeStruct {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return DateRangeStruct(start: yesterday.startOfDay, end: yesterday.endOfDay)
    }
    
    static func thisWeek() -> DateRangeStruct {
        return DateRangeStruct(start: Date().startOfWeek, end: Date().endOfWeek)
    }
    
    static func lastWeek() -> DateRangeStruct {
        let lastWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        return DateRangeStruct(start: lastWeek.startOfWeek, end: lastWeek.endOfWeek)
    }
    
    static func thisMonth() -> DateRangeStruct {
        return DateRangeStruct(start: Date().startOfMonth, end: Date().endOfMonth)
    }
    
    static func lastMonth() -> DateRangeStruct {
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return DateRangeStruct(start: lastMonth.startOfMonth, end: lastMonth.endOfMonth)
    }
    
    static func thisYear() -> DateRangeStruct {
        return DateRangeStruct(start: Date().startOfYear, end: Date().endOfYear)
    }
    
    static func lastYear() -> DateRangeStruct {
        let lastYear = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        return DateRangeStruct(start: lastYear.startOfYear, end: lastYear.endOfYear)
    }
    
    static func custom(start: Date, end: Date) -> DateRangeStruct {
        return DateRangeStruct(start: start, end: end)
    }
}

// MARK: - Date Utilities

struct DateUtilities {
    static func age(from birthDate: Date) -> Int {
        return Date().yearsSince(birthDate)
    }
    
    static func isLeapYear(_ year: Int) -> Bool {
        return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
    }
    
    static func daysInMonth(_ month: Int, year: Int) -> Int {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        
        guard let date = calendar.date(from: components) else { return 30 }
        let range = calendar.range(of: .day, in: .month, for: date)
        return range?.count ?? 30
    }
    
    static func startOfDay(for date: Date) -> Date {
        return Calendar.current.startOfDay(for: date)
    }
    
    static func endOfDay(for date: Date) -> Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay(for: date)) ?? date
    }
}
