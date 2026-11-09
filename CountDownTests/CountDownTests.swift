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

    @Test func legacyEventsKeepOriginalAppearance() throws {
        let sample = """
        {"id":"00000000-0000-0000-0000-000000000042","title":"Событие","date":{"year":2026,"month":4,"day":30},"palette":"coral","symbol":"star"}
        """
        let event = try JSONDecoder().decode(CountEvent.self, from: Data(sample.utf8))
        #expect(event.style.typeface == .editorial)
        #expect(event.style.scale == 1)
        #expect(event.style.textColorHex == "FFFFFF")
        #expect(event.style.unitPlacement == .beside)
    }

    @Test func cardStylePersistsInEventJSON() throws {
        var event = CountEvent(title: "Дата", date: CalendarDay(year: 2027, month: 1, day: 1))
        event.style = CardStyle(typeface: .soft, thickness: .light, scale: 1.3,
                                textColorHex: "F6CF59", alignment: .center, unitPlacement: .below)
        let encoded = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(CountEvent.self, from: encoded)
        #expect(decoded.style == event.style)
    }

    @Test func countUpStartsAtZeroAndAdvances() {
        let origin = utcCalendar.date(from: DateComponents(year: 2026, month: 11, day: 9,
                                                            hour: 12, minute: 10, second: 15))!
        let event = CountEvent(title: "Начало",
                               date: CalendarDay(date: origin, includesTime: true,
                                                 includesSeconds: true, calendar: utcCalendar),
                               countsUp: true)
        #expect(DayCount.reading(for: event, now: origin, calendar: utcCalendar).number == 0)
        #expect(DayCount.reading(for: event, now: origin, calendar: utcCalendar).unit == .minutes)
        let later = origin.addingTimeInterval(3_600)
        #expect(DayCount.reading(for: event, now: later, calendar: utcCalendar).unit == .hours)
        #expect(DayCount.reading(for: event, now: later, calendar: utcCalendar).number == 1)
    }

    @Test func secondsAndMaskColorRoundTrip() throws {
        let date = CalendarDay(year: 2026, month: 11, day: 9, hour: 20, minute: 12, second: 29)
        let event = CountEvent(title: "Секундомер", date: date,
                               maskOpacity: 0.8, maskColorHex: "E8C4F0", countsUp: true)
        let encoded = try JSONEncoder().encode(event)
        let restored = try JSONDecoder().decode(CountEvent.self, from: encoded)
        #expect(restored.countsUp)
        #expect(restored.maskColorHex == "E8C4F0")
        #expect(restored.date.second == 29)
    }

    @Test func olderPhotosKeepMaskAndCountdown() throws {
        let legacy = """
        {"id":"00000000-0000-0000-0000-000000000043","title":"Старое","date":{"year":2026,"month":4,"day":30},"palette":"coral","symbol":"star","mask":"plum","maskOpacity":0.55}
        """
        let event = try JSONDecoder().decode(CountEvent.self, from: Data(legacy.utf8))
        #expect(event.maskColorHex == "541F4A")
        #expect(!event.countsUp)
    }

    @Test func monthsAreCalendarAware() {
        let now = utcCalendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        let event = CountEvent(title: "Дата", date: CalendarDay(year: 2026, month: 4, day: 30))
        let next = EventMilestones.next(for: event, now: now, calendar: utcCalendar)
        #expect(next != nil)
    }
}
