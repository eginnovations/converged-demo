package com.eginnovations.demo.order;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * The deliberately slow method for the code-level diagnostics part of the demo.
 *
 * calculatePricingAndRisk() burns CPU/time on purpose so it dominates the call
 * graph for the Checkout transaction. Point an eG custom pointcut at:
 *
 *   com.eginnovations.demo.order.PricingService.calculatePricingAndRisk
 *
 * and it will surface as the slow method, with runFraudHeuristics() as the
 * offending child frame in the call graph.
 */
@Service
public class PricingService {

    private static final Logger log = LoggerFactory.getLogger(PricingService.class);

    /** Injected slowness in milliseconds; tune per demo without rebuilding. */
    @Value("${demo.pricing.delayMs:1500}")
    private long delayMs;

    public double calculatePricingAndRisk(double amount, List<String> items) {
        long start = System.currentTimeMillis();

        double discounted = applyPromotions(amount, items);
        double risk = runFraudHeuristics(discounted);   // <- hotspot child frame

        double finalPrice = Math.round((discounted + risk) * 100.0) / 100.0;
        log.info("Pricing computed in {} ms -> {}",
                System.currentTimeMillis() - start, finalPrice);
        return finalPrice;
    }

    private double applyPromotions(double amount, List<String> items) {
        // Flash-sale promo from the checkout banner: 10% off.
        return Math.round(amount * 0.90 * 100.0) / 100.0;
    }

    /**
     * The actual hotspot. Simulates an expensive risk model with a tight loop
     * plus a sleep so it is both CPU- and wall-clock-heavy — easy to spot in a
     * flame/call graph.
     */
    private double runFraudHeuristics(double amount) {
        // Busy work so CPU sampling attributes time here too.
        double acc = 0;
        for (int i = 0; i < 2_000_000; i++) {
            acc += Math.sqrt((i % 97) + amount) * Math.sin(i);
        }
        try {
            Thread.sleep(delayMs);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        // Tiny risk surcharge; value is not important, the time spent is.
        return Math.min(2.5, Math.abs(acc) % 3);
    }
}
