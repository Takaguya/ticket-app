// Calls to the Pin API. Every failure becomes an ApiError whose message can be shown
// to the admin as it is.

export const NETWORK_MESSAGE = "Can't reach Pin right now. Check your connection and try again."
const SERVER_MESSAGE = 'Something went wrong on Pin’s side. Please try again.'

/** A refused or failed request. `status` is 0 when the server could not be reached. */
export class ApiError extends Error {
  readonly status: number
  readonly code: string

  constructor(status: number, code: string, message: string) {
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.code = code
  }
}

export interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE'
  body?: unknown
  /** A file sent as the request body as it is (not JSON), e.g. a picture, with its own content type. */
  file?: Blob
  /** The admin's access token, sent as a bearer token. */
  token?: string | null
  signal?: AbortSignal
}

const baseUrl = (import.meta.env.VITE_API_BASE_URL ?? '/api').replace(/\/$/, '')

/**
 * The address of something the server serves, from the path it sends: an event's
 * picture is `/images/events/<id>?v=…` and is fetched from the same server as the API.
 */
export function apiUrl(path: string): string {
  return /^https?:\/\//.test(path) ? path : baseUrl + path
}

let sessionRejected: (() => void) | null = null

/** Called when the server refuses the access token (401): the session is over. */
export function onSessionRejected(handler: (() => void) | null): void {
  sessionRejected = handler
}

export async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const headers: Record<string, string> = { Accept: 'application/json' }
  if (options.file) headers['Content-Type'] = options.file.type || 'application/octet-stream'
  else if (options.body !== undefined) headers['Content-Type'] = 'application/json'
  if (options.token) headers.Authorization = `Bearer ${options.token}`

  let response: Response
  try {
    response = await fetch(baseUrl + path, {
      method: options.method ?? 'GET',
      headers,
      body: options.file ?? (options.body === undefined ? undefined : JSON.stringify(options.body)),
      signal: options.signal,
    })
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') throw error
    throw new ApiError(0, 'network', NETWORK_MESSAGE)
  }

  const data = parseJson(await response.text())
  if (response.ok) return data as T

  if (response.status === 401 && options.token) sessionRejected?.()
  const error = isApiErrorBody(data) ? data : null
  if (error) throw new ApiError(response.status, error.code, error.message)
  // No answer from Pin itself, e.g. the dev server's proxy could not reach the backend.
  if (response.status >= 502) throw new ApiError(response.status, 'network', NETWORK_MESSAGE)
  throw new ApiError(response.status, 'server_error', SERVER_MESSAGE)
}

function parseJson(text: string): unknown {
  if (!text) return undefined
  try {
    return JSON.parse(text)
  } catch {
    return undefined
  }
}

function isApiErrorBody(data: unknown): data is { code: string; message: string } {
  return (
    typeof data === 'object' &&
    data !== null &&
    typeof (data as { code?: unknown }).code === 'string' &&
    typeof (data as { message?: unknown }).message === 'string'
  )
}
