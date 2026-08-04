package com.eginnovations.demo.order;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import java.util.Map;
import java.util.UUID;

/**
 * Downstream 3rd-party service (remote-service exit call).
 *
 * Calls an external "payment gateway" over HTTP. In the demo this is a small
 * mock container that returns after a delay, so eG Enterprise shows it as a
 * slow third-party exit call on the transaction flow map. Swap the URL for a
 * real sandbox gateway anytime.
 */
@Component
public class PaymentGatewayClient {

    private static final Logger log = LoggerFactory.getLogger(PaymentGatewayClient.class);

    private final RestTemplate restTemplate;

    @Value("${payment.gateway.url:http://payment-gateway:8080/delay/1}")
    private String gatewayUrl;

    public PaymentGatewayClient(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    public String authorize(String orderId, double amount) {
        try {
            // Remote HTTP exit call to the third-party gateway.
            restTemplate.postForObject(gatewayUrl,
                    Map.of("orderId", orderId, "amount", amount), String.class);
        } catch (Exception e) {
            // Even on error we return a code; the point is the exit-call timing.
            log.warn("Payment gateway call issue: {}", e.getMessage());
        }
        String auth = "AUTH-" + UUID.randomUUID().toString().substring(0, 6).toUpperCase();
        log.info("Payment authorized order={} auth={}", orderId, auth);
        return auth;
    }
}
