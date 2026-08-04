package com.eginnovations.demo.storefront;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * Catalog API served by the storefront tier.
 *
 * Each endpoint sleeps for a configurable time so the browser renders its
 * content late. That late render is what drives the Core Web Vitals problems on
 * the pages (slow LCP on the home page, layout shift on the product page). In
 * APM these show up as slow storefront endpoints, so the browser symptom and
 * the backend cause line up in the same story.
 */
@RestController
@RequestMapping("/api")
public class CatalogController {

    @Value("${catalog.productsDelayMs:4300}")
    private long productsDelayMs;      // drives Home LCP (> 4000 ms)
    @Value("${catalog.productDelayMs:1200}")
    private long productDelayMs;
    @Value("${catalog.reviewsDelayMs:2500}")
    private long reviewsDelayMs;       // drives Product CLS (first shift)
    @Value("${catalog.relatedDelayMs:4500}")
    private long relatedDelayMs;       // drives Product CLS (second shift)

    private static final List<Map<String, Object>> PRODUCTS = List.of(
        prod("h1", "Aurora Noise-Cancelling Headphones", 129.00, "#0b4f8a"),
        prod("c1", "PowerLine USB-C Charger 65W",        24.00, "#12a150"),
        prod("s1", "Pulse Fitness Smartwatch",            89.00, "#8e44ad"),
        prod("k1", "Nimbus Mechanical Keyboard",          74.00, "#c0392b"),
        prod("m1", "Glide Wireless Mouse",                39.00, "#16a085"),
        prod("b1", "Boom Portable Bluetooth Speaker",     59.00, "#d35400")
    );

    private static Map<String, Object> prod(String id, String name, double price, String color) {
        return Map.of("id", id, "name", name, "price", price, "color", color);
    }

    private static void nap(long ms) {
        try { Thread.sleep(ms); } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
    }

    @GetMapping("/products")
    public List<Map<String, Object>> products() {
        nap(productsDelayMs);          // slow catalog service -> late LCP
        return PRODUCTS;
    }

    @GetMapping("/product")
    public Map<String, Object> product(@RequestParam String id) {
        nap(productDelayMs);
        return PRODUCTS.stream().filter(p -> id.equals(p.get("id"))).findFirst().orElse(PRODUCTS.get(0));
    }

    @GetMapping("/reviews")
    public List<Map<String, Object>> reviews(@RequestParam(required = false) String id) {
        nap(reviewsDelayMs);           // late reviews -> layout shift #1
        return List.of(
            Map.of("author", "Priya S.",  "stars", 5, "text", "Fantastic sound and the battery lasts for days."),
            Map.of("author", "Marcus L.", "stars", 4, "text", "Great value. Bluetooth pairing was instant."),
            Map.of("author", "Wei C.",    "stars", 5, "text", "Comfortable for long calls, noise cancelling is superb.")
        );
    }

    @GetMapping("/related")
    public List<Map<String, Object>> related(@RequestParam(required = false) String id) {
        nap(relatedDelayMs);           // late "bought together" -> layout shift #2
        return List.of(PRODUCTS.get(1), PRODUCTS.get(4), PRODUCTS.get(2));
    }
}
