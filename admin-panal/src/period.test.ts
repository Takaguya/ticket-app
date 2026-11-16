import { describe, expect, it } from 'vitest'

import { presets, samePeriod } from './period'

function preset(today: string, label: string) {
  return presets(today).find((choice) => choice.label === label)?.period
}

describe('presets', () => {
  it('counts back from Pin\'s today, both days included', () => {
    expect(preset('2026-11-14', 'Today')).toEqual({ from: '2026-11-14', to: '2026-11-14' })
    expect(preset('2026-11-14', 'Last 7 days')).toEqual({ from: '2026-11-08', to: '2026-11-14' })
    expect(preset('2026-11-14', 'Last 30 days')).toEqual({ from: '2026-10-16', to: '2026-11-14' })
    expect(preset('2026-11-14', 'This year')).toEqual({ from: '2026-01-01', to: '2026-11-14' })
  })

  it('leaves "This month" to the server, so it moves on with the calendar', () => {
    expect(preset('2026-11-14', 'This month')).toBeNull()
  })

  it('crosses months and years', () => {
    expect(preset('2026-03-03', 'Last 7 days')).toEqual({ from: '2026-02-25', to: '2026-03-03' })
    expect(preset('2026-03-14', 'Last month')).toEqual({ from: '2026-02-01', to: '2026-02-28' })
    expect(preset('2027-01-05', 'Last month')).toEqual({ from: '2026-12-01', to: '2026-12-31' })
  })
})

describe('samePeriod', () => {
  it('compares the days', () => {
    expect(samePeriod(null, null)).toBe(true)
    expect(samePeriod({ from: '2026-11-01', to: '2026-11-14' }, { from: '2026-11-01', to: '2026-11-14' })).toBe(true)
    expect(samePeriod({ from: '2026-11-01', to: '2026-11-14' }, null)).toBe(false)
  })
})
