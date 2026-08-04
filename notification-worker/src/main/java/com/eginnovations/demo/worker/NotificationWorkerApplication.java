package com.eginnovations.demo.worker;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.jms.annotation.EnableJms;

/**
 * Notification-worker tier.
 *
 * Consumes order-confirmation messages from the Artemis "order.notifications"
 * queue. Each message is processed slowly on purpose (single-threaded, with a
 * per-message delay), so when orders arrive faster than they are consumed the
 * queue depth grows — the "message queue pickup delay / backed-up messages"
 * scenario from the demo storyline.
 */
@SpringBootApplication
@EnableJms
public class NotificationWorkerApplication {

    public static void main(String[] args) {
        SpringApplication.run(NotificationWorkerApplication.class, args);
    }
}
