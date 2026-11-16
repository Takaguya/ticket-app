import { afterEach, describe, expect, it, vi } from 'vitest'

import { ApiError, NETWORK_MESSAGE, apiUrl, onSessionRejected, request } from './http'

/** A fake fetch that answers every call with a new response (a body can be read once). */
function answer(status: number, body?: unknown, raw?: string) {
  return vi.fn(
    async (_url: string, _init?: RequestInit) =>
      new Response(raw ?? (body === undefined ? null : JSON.stringify(body)), { status }),
  )
}

async function failure(promise: Promise<unknown>): Promise<ApiError> {
  try {
    await promise
  } catch (error) {
    if (error instanceof ApiError) return error
    throw error
  }
  throw new Error('The request did not fail')
}

afterEach(() => {
  vi.unstubAllGlobals()
  onSessionRejected(null)
})

describe('request', () => {
  it('sends JSON with the token and reads the answer', async () => {
    const fetch = answer(200, { id: 'm1' })
    vi.stubGlobal('fetch', fetch)

    const result = await request<{ id: string }>('/admin/merchants', { method: 'POST', body: { a: 1 }, token: 't0k' })

    expect(result).toEqual({ id: 'm1' })
    const [url, init] = fetch.mock.calls[0] as [string, RequestInit]
    expect(url).toBe('/api/admin/merchants')
    expect(init.method).toBe('POST')
    expect(init.body).toBe('{"a":1}')
    expect(init.headers).toMatchObject({ Authorization: 'Bearer t0k', 'Content-Type': 'application/json' })
  })

  it('answers nothing for 204', async () => {
    vi.stubGlobal('fetch', answer(204))
    await expect(request('/auth/otp', { method: 'POST', body: {} })).resolves.toBeUndefined()
  })

  it("passes on Pin's own message", async () => {
    vi.stubGlobal('fetch', answer(409, { code: 'rejected', message: 'Laugh PP is already suspended.' }))

    const error = await failure(request('/admin/merchants/x/suspend', { method: 'POST' }))

    expect(error.status).toBe(409)
    expect(error.code).toBe('rejected')
    expect(error.message).toBe('Laugh PP is already suspended.')
  })

  it('says Pin cannot be reached when there is no answer', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('Failed to fetch')))
    expect((await failure(request('/admin/events'))).message).toBe(NETWORK_MESSAGE)

    vi.stubGlobal('fetch', answer(502, undefined, 'Bad gateway'))
    expect((await failure(request('/admin/events'))).message).toBe(NETWORK_MESSAGE)
  })

  it('ends the session when the token is refused', async () => {
    const rejected = vi.fn()
    onSessionRejected(rejected)
    vi.stubGlobal('fetch', answer(401, { code: 'unauthorized', message: 'Please sign in again.' }))

    await failure(request('/admin/me', { token: 'old' }))
    expect(rejected).toHaveBeenCalledOnce()

    await failure(request('/admin/auth/verify', { method: 'POST', body: {} }))
    expect(rejected).toHaveBeenCalledOnce()
  })

  it('sends a file as the body as it is, with its own content type and not as JSON', async () => {
    const fetch = answer(200, { imageUrl: '/images/events/e1?v=5' })
    vi.stubGlobal('fetch', fetch)
    const picture = new File([new Uint8Array([1, 2, 3])], 'poster.png', { type: 'image/png' })

    const result = await request<{ imageUrl: string }>('/admin/events/e1/image', {
      method: 'PUT',
      file: picture,
      token: 't0k',
    })

    expect(result).toEqual({ imageUrl: '/images/events/e1?v=5' })
    const [url, init] = fetch.mock.calls[0] as [string, RequestInit]
    expect(url).toBe('/api/admin/events/e1/image')
    expect(init.method).toBe('PUT')
    expect(init.body).toBe(picture)
    expect(init.headers).toMatchObject({ Authorization: 'Bearer t0k', 'Content-Type': 'image/png' })
  })

  it('calls a file with no known type an octet stream', async () => {
    const fetch = answer(200, {})
    vi.stubGlobal('fetch', fetch)

    await request('/admin/events/e1/image', { method: 'PUT', file: new File([new Uint8Array([1])], 'poster') })

    const [, init] = fetch.mock.calls[0] as [string, RequestInit]
    expect(init.headers).toMatchObject({ 'Content-Type': 'application/octet-stream' })
  })

  it('deletes with the token and answers nothing for 204', async () => {
    const fetch = answer(204)
    vi.stubGlobal('fetch', fetch)

    await expect(request('/admin/events/e1/image', { method: 'DELETE', token: 't0k' })).resolves.toBeUndefined()

    const [, init] = fetch.mock.calls[0] as [string, RequestInit]
    expect(init.method).toBe('DELETE')
    expect(init.body).toBeUndefined()
    expect(init.headers).toMatchObject({ Authorization: 'Bearer t0k' })
  })

  it("shows the server's reason for a refused picture", async () => {
    vi.stubGlobal('fetch', answer(400, { code: 'rejected', message: 'That file is not a picture. Choose a JPEG or PNG image.' }))

    const error = await failure(request('/admin/events/e1/image', { method: 'PUT', file: new File([new Uint8Array([1])], 'a.png') }))

    expect(error.status).toBe(400)
    expect(error.message).toBe('That file is not a picture. Choose a JPEG or PNG image.')
  })
})

describe('apiUrl', () => {
  it('puts the API address in front of a path the server sends, so a picture comes from the same server', () => {
    expect(apiUrl('/images/events/e1?v=5')).toBe('/api/images/events/e1?v=5')
  })

  it('leaves a complete address as it is', () => {
    expect(apiUrl('https://cdn.example/a.jpg')).toBe('https://cdn.example/a.jpg')
  })
})
