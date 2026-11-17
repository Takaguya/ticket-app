package com.ticket.app.backend.identity.service;

import com.ticket.app.backend.shared.model.PhoneNumber;

/** Sends a text message. Implemented by an SMS provider in infrastructure. */
public interface SmsSender {

    void send(PhoneNumber phone, String message);
}
