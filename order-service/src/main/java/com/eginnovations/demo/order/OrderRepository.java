package com.eginnovations.demo.order;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.Timestamp;

/**
 * SQL exit calls for the Checkout transaction.
 *
 * saveOrder() runs a SELECT that is intentionally slow so eG Enterprise's SQL
 * exit-call visibility and Database Visibility have something to show. The
 * slowness comes from MySQL's SLEEP() plus a scan-style aggregate, which also
 * lets the DBA-side view (Database Visibility) demonstrate a slow query.
 */
@Repository
public class OrderRepository {

    private static final Logger log = LoggerFactory.getLogger(OrderRepository.class);

    private final JdbcTemplate jdbc;

    /** Seconds of DB-side sleep injected into the slow SELECT. */
    @Value("${demo.sql.sleepSeconds:1}")
    private int sleepSeconds;

    public OrderRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void saveOrder(String orderId, double amount) {
        // Slow read: SLEEP() makes this query the obvious slow SQL exit call.
        // Named comment tag helps identify it in eG SQL / DB Visibility views.
        Integer recent = jdbc.queryForObject(
                "SELECT /* checkout_risk_lookup */ COUNT(*) " +
                "FROM orders WHERE created_at > (NOW() - INTERVAL 1 DAY) AND SLEEP(?) = 0",
                Integer.class, sleepSeconds);

        jdbc.update(
                "INSERT INTO orders (order_id, amount, status, created_at) VALUES (?, ?, ?, ?)",
                orderId, amount, "CONFIRMED", new Timestamp(System.currentTimeMillis()));

        log.info("Order {} persisted (recent-orders scan returned {})", orderId, recent);
    }
}
