package com.eginnovations.demo.storefront;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.client.RestTemplate;
import org.springframework.context.annotation.Bean;

/**
 * Storefront tier.
 *
 * This is the browser-facing JVM. It serves the checkout page (with the
 * intentional Core Web Vitals / CLS problem and the RUM snippet placeholder)
 * and proxies the /placeOrder Ajax call to the order-service tier so that
 * eG Enterprise can correlate the slow browser Ajax request to the server-side
 * Checkout business transaction.
 */
@SpringBootApplication
public class StorefrontApplication {

    public static void main(String[] args) {
        SpringApplication.run(StorefrontApplication.class, args);
    }

    @Bean
    public RestTemplate restTemplate() {
        return new RestTemplate();
    }
}
