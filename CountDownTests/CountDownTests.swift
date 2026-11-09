import Foundation
import Testing
@testable import CountDown

struct CountDownTests {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func daysAcrossDST() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 28, hour: 22))!
        #expect(DayCount.signedDays(to: CalendarDay(year: 2026, month: 3, day: 30), from: now, calendar: calendar) == 2)
    }

    @Test func autoChangesFromDaysToHoursToMinutes() {
        let target = CalendarDay(year: 2027, month: 1, day: 1, hour: 12, minute: 0)
        let event = CountEvent(title: "Новый год", date: target)
        let far = utcCalendar.date(from: DateComponents(year: 2026, month: 12, day: 30, hour: 10))!
        let hours = utcCalendar.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 18))!
        let minutes = utcCalendar.date(from: DateComponents(year: 2027, month: 1, day: 1, hour: 11, minute: 25))!
        #expect(DayCount.reading(for: event, now: far, calendar: utcCalendar).unit == .days)
        #expect(DayCount.reading(for: event, now: hours, calendar: utcCalendar).unit == .hours)
        #expect(DayCount.reading(for: event, now: minutes, calendar: utcCalendar).number == 35)
        #expect(DayCount.reading(for: event, now: minutes, calendar: utcCalendar).unit == .minutes)
    }

    @Test func pastAutomaticShowsCalendarDays() {
        let now = utcCalendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 20))!
        let event = CountEvent(title: "Дата", date: CalendarDay(year: 2026, month: 4, day: 30))
        let reading = DayCount.reading(for: event, now: now, calendar: utcCalendar)
        #expect(reading.unit == .days)
        #expect(!reading.isFuture)
        #expect(reading.number > 100)
    }

    @Test func previousJSONDecodesWithDefaults() throws {
        let id = UUID()
        let legacy = """
        {"id":"\(id.uuidString)","title":"Старая дата","date":{"year":2026,"month":4,"day":30},"palette":"ocean","symbol":"calendar"}
        """
        let event = try JSONDecoder().decode(CountEvent.self, from: Data(legacy.utf8))
        #expect(event.note == "")
        #expect(event.unit == .automatic)
        #expect(event.showsMilestones)
        #expect(event.photoFilename == nil)
        #expect(event.date.hour == nil)
    }

    @Test func leapYearAndWordForms() {
        let start = utcCalendar.date(from: DateComponents(year: 2028, month: 2, day: 28))!
        #expect(DayCount.signedDays(to: CalendarDay(year: 2028, month: 3, day: 1), from: start, calendar: utcCalendar) == 2)
        #expect(DayCount.dayWord(1) == "день")
        #expect(DayCount.dayWord(2) == "дня")
        #expect(DayCount.dayWord(11) == "дней")
    }

    @Test func monthsAreCalendarAware() {
        let now = utcCalendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        let event = CountEvent(title: "Дата", date: CalendarDay(year: 2026, month: 4, day: 30))
        let next = EventMilestones.next(for: event, now: now, calendar: utcCalendar)
        #expect(next != nil)
    }
}
