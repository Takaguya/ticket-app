import { describe, expect, it } from 'vitest'

import { pageNumbers } from './pagination'

describe('pageNumbers', () => {
  it('shows every page when there are few', () => {
    expect(pageNumbers(1, 1)).toEqual([1])
    expect(pageNumbers(1, 5)).toEqual([1, 2, 3, 4, 5])
  })

  it('shows the first and last pages and the current one with its neighbours', () => {
    expect(pageNumbers(25, 50)).toEqual([1, 'gap', 24, 25, 26, 'gap', 50])
  })

  it('shows a few more pages near either end', () => {
    expect(pageNumbers(1, 50)).toEqual([1, 2, 3, 4, 'gap', 50])
    expect(pageNumbers(50, 50)).toEqual([1, 'gap', 47, 48, 49, 50])
  })

  it('shows a single left-out page instead of a gap', () => {
    expect(pageNumbers(4, 50)).toEqual([1, 2, 3, 4, 5, 'gap', 50])
    expect(pageNumbers(47, 50)).toEqual([1, 'gap', 46, 47, 48, 49, 50])
  })
})
