import Foundation
import Testing
@testable import CountDown

struct CountDownTests {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func futureAndPast() {
        let start = utcCalendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 15))!
        #expect(DayCount.signedDays(to: CalendarDay(year: 2026, month: 11, day: 11), from: start, calendar: utcCalendar) == 2)
        #expect(DayCount.signedDays(to: CalendarDay(year: 2026, month: 11, day: 7), from: start, calendar: utcCalendar) == -2)
    }

    @Test func sameDayEvenAtNight() {
        let start = utcCalendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 23, minute: 59))!
        #expect(DayCount.signedDays(to: CalendarDay(year: 2026, month: 11, day: 9), from: start, calendar: utcCalendar) == 0)
    }

    @Test func daylightSavingTimeIsCalendarBased() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 28, hour: 22))!
        #expect(DayCount.signedDays(to: CalendarDay(year: 2026, month: 3, day: 30), from: start, calendar: cal) == 2)
    }

    @Test func leapYear() {
        let start = utcCalendar.date(from: DateComponents(year: 2028, month: 2, day: 28))!
        #expect(DayCount.signedDays(to: CalendarDay(year: 2028, month: 3, day: 1), from: start, calendar: utcCalendar) == 2)
    }

    @Test func wordForms() {
        #expect(DayCount.dayWord(1) == "день")
        #expect(DayCount.dayWord(2) == "дня")
        #expect(DayCount.dayWord(5) == "дней")
        #expect(DayCount.dayWord(11) == "дней")
        #expect(DayCount.dayWord(21) == "день")
    }

    @Test func jsonRoundTrip() throws {
        let original = CountEvent(title: "Путешествие", date: CalendarDay(year: 2027, month: 2, day: 20), palette: .ocean)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CountEvent.self, from: encoded)
        #expect(decoded == original)
    }
}
