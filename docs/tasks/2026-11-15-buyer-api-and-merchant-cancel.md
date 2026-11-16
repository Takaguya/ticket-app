# Task: buyer API, merchants see buyer bookings, merchants cancel bookings

Given 2026-11-15. The request, as written:

> the backend for buyer api need to have that as well and let merchant can see and also have can cancel
> ticket from merchant side

Meaning: the backend gets a buyer API covering what the user app does, so the user app can run on the
server instead of its mock; bookings buyers make show up for the merchant; and the merchant can cancel
a booking from the merchant app.

## Decisions the user made (asked 2026-11-15)

| Question | Answer |
|---|---|
| Scope of the buyer API this round | **Events first.** Buyer sign-in and registration, merchants' approved events, race runner details, promo codes, checkout, the buyer's bookings. Bus, cinema and admission come in a later round; with the server, the user app shows them as "Coming soon". |
| Who cancels in the merchant app | **The owner only.** Scanners see cancelled bookings but cannot cancel. |
| Money when a merchant cancels an online booking | **Full refund, payout adjusted.** The buyer gets everything back, to how they paid (paying is simulated). If Pin already paid the merchant for that booking, the merchant's share comes off its next payout. |
| Reason | **The owner picks one**: buyer asked, event changed or called off, sold by mistake, other. The buyer's ticket shows it. |
| Who pays for Pin's promo codes (D2D10, FIRST) | **Pin.** The business is paid on the full ticket price; Pin's commission is on the full price; the discount comes out of Pin's share. The buyer's refund is what they paid; a refund taken back after a payout is what that payout paid for the booking. |
| Event kinds (asked after the full app run) | **Marathon, Concert or Show**, chosen by the merchant in Create event. Marathon asks the user app's runner details after Select tickets (one runner, one ticket per booking); Concert and Show go straight to checkout, nothing extra — as the user app prototype does. It replaces the hidden race flag. The kind sets the label and icon buyers see. |
| Race runner details for merchants | **The whole team sees them** (owner and scanners) on the booking in the merchant app: name, phone, email, gender, age, nationality, emergency contact, T-shirt size. Also in the owner's CSV export. |

Not wanted: buyers cancelling their own bookings (declined in the user app's booking round). Do not build it.

## Steps

### 1. Backend: the owner cancels a booking (written by the main session, not reviewed or tested yet)

- `POST /merchant/bookings/{id}/cancel {reason}`, owners only (scanners 403); `reason` is `buyerAsked`,
  `eventChanged`, `soldByMistake` or `other` (anything else 400 "Choose why the booking is cancelled.").
- The whole booking is cancelled. Refused (409) when it is checked in, or its event's day has passed.
  Cancelling a cancelled booking answers it unchanged (the first reason stays). Another business's
  booking, or an ID that is not one, is 404.
- Booking JSON carries `cancellation: {at, staffName, reason, refundCents}` (null unless the business
  cancelled it). `refundCents` is everything paid for an online booking, 0 for a door sale (the business
  pays that back itself).
- Payouts: a paid-out booking cancelled since has its business share (total minus Pin's commission)
  taken off the next payout, once. While refunds are more than new sales, nothing is owed. Payout JSON
  (merchant and admin) gains `refundsCents`.
- A cancel and a payout never cross (both lock the business); a cancel and a check-in never cross (both
  lock the booking).

### 2. Backend: the buyer API (being designed by `architect`, then written by `code-writer`)

- Buyer accounts: phone + SMS code (`/auth/otp`, `/auth/verify` with `app=user`); registration with name,
  gender, date of birth, optional email; sign-out; who am I. Buyer sessions kept apart from merchant and
  admin sessions (each kind gets 403 on the others' endpoints).
- Catalogue: approved events of active businesses of type `events`, not started yet, with what the user
  app's event page shows (venue detail, about, organiser, policy, ticket types with descriptions,
  whether a race needs runner details).
- Promo codes as in the user app's mock: `D2D10` 10% off; `FIRST` $2 off orders of $5 or more.
- Race runner details: one runner per booking; can be saved for the next race.
- Checkout: the server prices it; refuses more than 8 tickets, more than is left, a started event, an
  event not on sale, a missing runner, a wrong promo code; never sells the last ticket twice.
- The buyer's bookings, each with its event, status and, when the merchant cancelled it, the reason,
  the business, the refund.
- Merchants see these bookings as online bookings in the endpoints they already use.
- Demo data: the user app's demo buyer Sokha Chan (`+85510222333`) with a booking.

### 3. Merchant app: "Cancel booking" for owners

On the booking detail: owners of an open booking pick a reason and confirm; the booking then shows who
cancelled it, why, and the refund (or "give the buyer their money back" for a door sale). Scanners don't
see the button. Works with the mock and with the server. Finance shows refunds taken off payouts.

### 4. User app: the server for events

With `USE_MOCK_API=false`: sign-in and registration, the events catalogue, promo codes, runner details,
checkout and bookings come from the server; Bus, Cinema and Admission show "Coming soon". A cancelled
booking shows as cancelled on Activity and on its ticket, with the reason, the business and the refund.

### 5. Admin panel and documentation

The admin Payouts page shows refunds taken back. READMEs (backend, merchant app, user app, admin panel)
describe the new endpoints and screens.

## The user's rules for this work

- Agents do the work: `architect` designs, `code-writer` (Sonnet) writes, `code-reviewer-tester` reviews.
  The main session coordinates, one agent at a time.
- Files change only through Edit/Write, one at a time, each approved by the user. No shell edits.
- No backend tests until the user says so.
- No commits, pushes, package installs or deleting files without asking.

## Review checklist (for `code-reviewer-tester`)

Check every point above against the code, step by step: each decision honoured, each refusal with its
status and message, the payout maths and refund bookkeeping, the locks, session separation, the demo
data, the README updates, and that the merchant app, user app and admin panel can read every JSON shape
that changed (changes must only add fields).
