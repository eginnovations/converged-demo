package com.eginnovations.demo.worker;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jms.annotation.JmsListener;
import org.springframework.stereotype.Component;

import java.util.concurrent.atomic.AtomicLong;

/**
 * Deliberately slow consumer.
 *
 * Concurrency is pinned to 1 (see application.yml) and each message takes
 * demo.consumer.processingMs to handle. Send orders faster than that and the
 * "order.notifications" queue backs up, which is exactly what the demo shows as
 * consumer pickup delay.
 */
@Component
public class OrderConsumer {

    private static final Logger log = LoggerFactory.getLogger(OrderConsumer.class);

    private final AtomicLong processed = new AtomicLong();

    @Value("${demo.consumer.processingMs:4000}")
    private long processingMs;

    @JmsListener(destination = "order.notifications")
    public void onOrder(String message) {
        long n = processed.incrementAndGet();
        log.info("Picking up message #{}: {}", n, message);
        try {
            // Slow processing (e.g. rendering + emailing a receipt).
            Thread.sleep(processingMs);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        log.info("Finished message #{} after {} ms", n, processingMs);
    }
}
