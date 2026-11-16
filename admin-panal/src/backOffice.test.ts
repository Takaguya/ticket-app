import { beforeEach, describe, expect, it, vi } from 'vitest'

import { adminApi } from './api/admin'
import { ApiError } from './api/http'
import type { AdminEvent, Merchant } from './api/types'
import {
  approveMerchant,
  awaitingEvents,
  backOffice,
  markPaid,
  pendingMerchants,
  refresh,
  removeEventImage,
  resetBackOffice,
  setEventImage,
} from './backOffice'
import { toast } from './toast'

vi.mock('./api/admin', () => ({
  adminApi: {
    overview: vi.fn(),
    merchants: vi.fn(),
    events: vi.fn(),
    payouts: vi.fn(),
    approveMerchant: vi.fn(),
    pay: vi.fn(),
    setEventImage: vi.fn(),
    removeEventImage: vi.fn(),
  },
}))

const api = vi.mocked(adminApi)

const pending: Merchant = {
  id: 'm5',
  name: 'Siem Reap Arts Collective',
  type: 'events',
  status: 'pending',
  owner: { name: 'Chenda Ouk', phone: '+85592114507' },
  events: 1,
  onlineSalesCents: 0,
  commissionCents: 0,
  registeredAt: '2026-11-10T09:00:00',
}

function serverHas(merchants: Merchant[]) {
  api.overview.mockResolvedValue({
    period: { from: '2026-11-01', to: '2026-11-14' },
    today: '2026-11-14',
    commissionRate: 5,
  })
  api.merchants.mockResolvedValue(merchants)
  api.events.mockResolvedValue([
    {
      id: 'e5',
      name: 'Angkor Sunset Music Fest',
      venue: 'Angkor Eye Field, Siem Reap',
      startsAt: '2027-01-16T16:00:00',
      merchantId: 'm5',
      merchantName: 'Siem Reap Arts Collective',
      status: 'awaitingApproval',
      sold: 0,
      capacity: 1500,
    },
  ])
  api.payouts.mockResolvedValue({ owed: [], paid: [] })
}

beforeEach(() => {
  vi.resetAllMocks()
  resetBackOffice()
})

describe('backOffice', () => {
  it('loads everything the pages show', async () => {
    serverHas([pending])

    await refresh()

    expect(backOffice.loaded).toBe(true)
    expect(backOffice.error).toBeNull()
    expect(pendingMerchants.value.map((m) => m.name)).toEqual(['Siem Reap Arts Collective'])
    expect(awaitingEvents.value.map((e) => e.name)).toEqual(['Angkor Sunset Music Fest'])
  })

  it('keeps the error to show when loading fails', async () => {
    serverHas([pending])
    api.events.mockRejectedValue(new ApiError(503, 'unavailable', "Pin can't save right now."))

    await refresh()

    expect(backOffice.loaded).toBe(false)
    expect(backOffice.error).toBe("Pin can't save right now.")
  })

  it('approves, says so and reloads to show what the server decided', async () => {
    serverHas([pending])
    api.approveMerchant.mockResolvedValue({ id: 'm5', name: pending.name, status: 'active' })
    await refresh()
    serverHas([{ ...pending, status: 'active' }])

    await approveMerchant(pending)

    expect(api.approveMerchant).toHaveBeenCalledWith('m5')
    expect(toast.message).toBe('Siem Reap Arts Collective is approved')
    expect(pendingMerchants.value).toHaveLength(0)
  })

  it("shows the server's refusal and still reloads", async () => {
    serverHas([pending])
    api.pay.mockRejectedValue(new ApiError(409, 'rejected', 'The amount owed is now $12.00.'))

    await markPaid({
      merchantId: 'm1',
      merchantName: 'Khmer Runners Club',
      grossCents: 1000,
      commissionCents: 50,
      netCents: 950,
      bookingCount: 1,
    })

    expect(api.pay).toHaveBeenCalledWith('m1', 950)
    expect(toast.message).toBe('The amount owed is now $12.00.')
    expect(toast.tone).toBe('error')
    expect(api.payouts).toHaveBeenCalled()
  })

  describe('event pictures', () => {
    const picture = new File([new Uint8Array([1, 2, 3])], 'poster.png', { type: 'image/png' })

    /** The one event the server has (a copy), loaded by the test's own `refresh()`. */
    function theEvent(): AdminEvent {
      const event = backOffice.events[0]
      if (!event) throw new Error('The test has not loaded the event')
      return { ...event }
    }

    it('sets the picture, says so and reloads the list to show the new address', async () => {
      serverHas([pending])
      await refresh()
      const event = theEvent()
      api.setEventImage.mockResolvedValue({ imageUrl: '/images/events/e5?v=9' })
      serverHas([pending])
      api.events.mockResolvedValue([{ ...event, imageUrl: '/images/events/e5?v=9' }])

      await setEventImage(event, picture)

      expect(api.setEventImage).toHaveBeenCalledWith('e5', picture)
      expect(toast.message).toBe('The picture of Angkor Sunset Music Fest is updated')
      expect(toast.tone).toBe('info')
      expect(backOffice.events[0]?.imageUrl).toBe('/images/events/e5?v=9')
    })

    it("shows the server's reason when it refuses the picture, and still reloads", async () => {
      serverHas([pending])
      await refresh()
      api.setEventImage.mockRejectedValue(
        new ApiError(400, 'rejected', 'That file is not a picture. Choose a JPEG or PNG image.'),
      )

      await setEventImage(theEvent(), picture)

      expect(toast.message).toBe('That file is not a picture. Choose a JPEG or PNG image.')
      expect(toast.tone).toBe('error')
      expect(api.events).toHaveBeenCalledTimes(2)
    })

    it('removes the picture and reloads', async () => {
      serverHas([pending])
      await refresh()
      const event = { ...theEvent(), imageUrl: '/images/events/e5?v=9' }
      api.removeEventImage.mockResolvedValue(undefined)

      await removeEventImage(event)

      expect(api.removeEventImage).toHaveBeenCalledWith('e5')
      expect(toast.message).toBe('The picture of Angkor Sunset Music Fest is removed')
    })

    it('does nothing twice at once for the same event', async () => {
      serverHas([pending])
      await refresh()
      const event = theEvent()
      let finish: (value: { imageUrl: string }) => void = () => {}
      api.setEventImage.mockReturnValue(new Promise((resolve) => (finish = resolve)))

      const first = setEventImage(event, picture)
      await setEventImage(event, picture)
      finish({ imageUrl: '/images/events/e5?v=1' })
      await first

      expect(api.setEventImage).toHaveBeenCalledTimes(1)
    })
  })
})
