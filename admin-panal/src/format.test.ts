import { describe, expect, it } from 'vitest'

import { date, dateTime, eventDate, initials, money, percent, period, phone, refunds, shortName } from './format'

describe('format', () => {
  it('writes refunds taken off a payout, or a dash for none', () => {
    expect(refunds(1500)).toBe('−$15.00')
    expect(refunds(0)).toBe('—')
    expect(refunds(undefined)).toBe('—')
  })

  it('writes cents as dollars', () => {
    expect(money(302100)).toBe('$3,021.00')
    expect(money(0)).toBe('$0.00')
    expect(money(1680)).toBe('$16.80')
  })

  it('writes dates as written, without time zones', () => {
    expect(date('2026-11-19T06:00:00')).toBe('19 Nov 2026')
    expect(date('2027-01-16')).toBe('16 Jan 2027')
    expect(dateTime('2026-11-12T10:05:00')).toBe('12 Nov, 10:05')
  })

  it("calls Pin's today 'Today'", () => {
    expect(eventDate('2026-11-14T05:30:00', '2026-11-14')).toBe('Today')
    expect(eventDate('2026-11-22T19:00:00', '2026-11-14')).toBe('22 Nov 2026')
    expect(eventDate('2026-11-14T05:30:00', undefined)).toBe('14 Nov 2026')
  })

  it('writes the period like the design', () => {
    expect(period('2026-11-01', '2026-11-14')).toBe('1–14 Nov 2026')
    expect(period('2026-11-01', '2026-11-01')).toBe('1 Nov 2026')
  })

  it('writes Cambodian numbers as people do', () => {
    expect(phone('+85512345678')).toBe('012 345 678')
    expect(phone('+855961234567')).toBe('096 123 4567')
  })

  it('shortens names for the sidebar', () => {
    expect(shortName('Moniroth Prak')).toBe('Moniroth P.')
    expect(shortName('Moniroth')).toBe('Moniroth')
    expect(initials('Moniroth Prak')).toBe('MP')
    expect(initials('Dara')).toBe('D')
    expect(percent(5)).toBe('5%')
    expect(percent(7.5)).toBe('7.5%')
  })
})
