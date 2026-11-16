package com.ticket.app.backend.identity.domain;

import com.ticket.app.backend.shared.domain.PhoneNumber;

/** Sends a text message. Implemented by an SMS provider in infrastructure. */
public interface SmsSender {

    void send(PhoneNumber phone, String message);
}
