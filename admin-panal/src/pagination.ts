// Which page numbers a pager shows: the first and last pages, the current one with its
// neighbours, and a gap where pages are left out, e.g. 1 … 24 25 26 … 50.

export type PageItem = number | 'gap'

export function pageNumbers(current: number, last: number): PageItem[] {
  const shown = new Set([1, last, current - 1, current, current + 1])
  // Near either end, a few more pages, so the row does not shrink there.
  if (current <= 3) [2, 3, 4].forEach((page) => shown.add(page))
  if (current >= last - 2) [last - 3, last - 2, last - 1].forEach((page) => shown.add(page))

  const pages = [...shown].filter((page) => page >= 1 && page <= last).sort((a, b) => a - b)
  const items: PageItem[] = []
  let previous = 0
  for (const page of pages) {
    // A gap of one page shows that page instead: "…" would take as much room.
    if (page - previous === 2) items.push(previous + 1)
    else if (page - previous > 2) items.push('gap')
    items.push(page)
    previous = page
  }
  return items
}
