import { ref } from 'vue'

/** What is typed in the header's search box. Each page filters by it; it clears when the page changes. */
export const pageSearch = ref('')

/** True when one of `values` contains the search text, ignoring case. An empty search matches all. */
export function matchesSearch(...values: (string | number | null | undefined)[]): boolean {
  const query = pageSearch.value.trim().toLowerCase()
  return query === '' || values.some((value) => String(value ?? '').toLowerCase().includes(query))
}
