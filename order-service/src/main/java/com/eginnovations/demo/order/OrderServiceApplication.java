package com.eginnovations.demo.order;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.jms.annotation.EnableJms;
import org.springframework.web.client.RestTemplate;

/**
 * Order-service tier.
 *
 * Hosts the Checkout business transaction. Within a single POST /placeOrder it:
 *   1. runs a deliberately slow pricing/risk method (custom-pointcut target),
 *   2. issues a slow SQL query against MySQL (SQL exit-call visibility),
 *   3. makes an HTTP exit call to a 3rd-party payment gateway,
 *   4. publishes an order-confirmation message to ActiveMQ Artemis.
 */
@SpringBootApplication
@EnableJms
public class OrderServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(OrderServiceApplication.class, args);
    }

    @Bean
    public RestTemplate restTemplate() {
        return new RestTemplate();
    }
}
