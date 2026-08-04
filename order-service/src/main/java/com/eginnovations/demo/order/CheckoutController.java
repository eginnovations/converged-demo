package com.eginnovations.demo.order;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * The Checkout business transaction (BTM) entry point.
 *
 * This method is the single server-side transaction that eG Enterprise tracks
 * end to end. Each numbered step below maps to a distinct capability in the
 * demo storyline: slow method, SQL query, downstream exit call, MQ publish.
 */
@RestController
public class CheckoutController {

    private static final Logger log = LoggerFactory.getLogger(CheckoutController.class);

    private final PricingService pricingService;
    private final OrderRepository orderRepository;
    private final PaymentGatewayClient paymentGatewayClient;
    private final OrderPublisher orderPublisher;

    public CheckoutController(PricingService pricingService,
                             OrderRepository orderRepository,
                             PaymentGatewayClient paymentGatewayClient,
                             OrderPublisher orderPublisher) {
        this.pricingService = pricingService;
        this.orderRepository = orderRepository;
        this.paymentGatewayClient = paymentGatewayClient;
        this.orderPublisher = orderPublisher;
    }

    @SuppressWarnings("unchecked")
    @PostMapping("/placeOrder")
    public Map<String, Object> placeOrder(@RequestBody Map<String, Object> cart) {
        String orderId = "ORD-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        double amount = cart.get("amount") instanceof Number
                ? ((Number) cart.get("amount")).doubleValue() : 0.0;
        List<String> items = (List<String>) cart.getOrDefault("items", List.of());

        log.info("Checkout START order={} amount={}", orderId, amount);

        // (1) SLOW METHOD — the code-level hotspot. This is the natural target
        //     for a custom pointcut so it shows up by name in the call graph.
        double finalPrice = pricingService.calculatePricingAndRisk(amount, items);

        // (2) SQL EXIT CALL — persist the order via a query that is intentionally
        //     slow (see OrderRepository), for SQL exit-call + DB Visibility.
        orderRepository.saveOrder(orderId, finalPrice);

        // (3) DOWNSTREAM 3RD-PARTY EXIT CALL — HTTP call to the payment gateway.
        String authCode = paymentGatewayClient.authorize(orderId, finalPrice);

        // (4) MESSAGE QUEUE PUBLISH — hand off to the async notification pipeline.
        //     The consumer is deliberately slow, so this queue backs up.
        orderPublisher.publishOrderConfirmation(orderId, finalPrice, authCode);

        log.info("Checkout DONE order={} price={} auth={}", orderId, finalPrice, authCode);

        return Map.of(
                "orderId", orderId,
                "amount", finalPrice,
                "authCode", authCode,
                "status", "CONFIRMED"
        );
    }
}
