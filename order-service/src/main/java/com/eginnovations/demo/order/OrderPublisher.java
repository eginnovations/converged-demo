package com.eginnovations.demo.order;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jms.core.JmsTemplate;
import org.springframework.stereotype.Component;

/**
 * Publishes an order-confirmation message to ActiveMQ Artemis.
 *
 * The producer is fast; the consumer (notification-worker) is deliberately
 * slow. Under load the "order.notifications" queue depth grows — that backlog
 * is the "message queue pickup delay / backed-up messages" scenario.
 */
@Component
public class OrderPublisher {

    private static final Logger log = LoggerFactory.getLogger(OrderPublisher.class);

    public static final String QUEUE = "order.notifications";

    private final JmsTemplate jmsTemplate;

    public OrderPublisher(JmsTemplate jmsTemplate) {
        this.jmsTemplate = jmsTemplate;
    }

    public void publishOrderConfirmation(String orderId, double amount, String authCode) {
        String payload = String.format(
                "{\"orderId\":\"%s\",\"amount\":%.2f,\"authCode\":\"%s\"}",
                orderId, amount, authCode);
        jmsTemplate.convertAndSend(QUEUE, payload);
        log.info("Queued confirmation for order {} on '{}'", orderId, QUEUE);
    }
}
