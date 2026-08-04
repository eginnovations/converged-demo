package com.eginnovations.demo.storefront;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;

import java.util.Map;

/**
 * Server-side entry point for the browser Ajax call.
 *
 * The browser fires POST /api/placeOrder (this is the slow Ajax request the
 * demo storyline talks about). This tier immediately forwards the request to
 * the order-service tier's /placeOrder endpoint. Keeping the browser Ajax path
 * (/api/placeOrder) distinct from the backend business transaction (/placeOrder)
 * is what lets eG Enterprise draw the Browser-RUM -> APM correlation and follow
 * the transaction across application tiers.
 */
@RestController
@RequestMapping("/api")
public class CheckoutProxyController {

    private final RestTemplate restTemplate;

    @Value("${order.service.url:http://order-service:8081}")
    private String orderServiceUrl;

    public CheckoutProxyController(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    @PostMapping("/placeOrder")
    public ResponseEntity<Object> placeOrder(@RequestBody Map<String, Object> cart) {
        // Exit call from the storefront tier to the order-service tier.
        // eG Enterprise sees this as a remote-service exit call and stitches the
        // two tiers together on the transaction flow map.
        Object response = restTemplate.postForObject(
                orderServiceUrl + "/placeOrder", cart, Object.class);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "UP", "tier", "storefront");
    }
}
