package com.eginnovations.demo.storefront;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

/**
 * Maps clean page URLs to their static HTML files so each step of the shopping
 * flow has its own tidy URL (and therefore its own page in Browser RUM):
 *   /product  /cart  /checkout  /confirmation
 * The home page ("/") is served from index.html automatically.
 */
@Controller
public class PageController {

    // Landing page is /index (home). "/" redirects to it so RUM shows a named page.
    @GetMapping("/")
    public String root() { return "redirect:/index"; }

    @GetMapping("/index")
    public String index() { return "forward:/index.html"; }

    @GetMapping("/login")
    public String login() { return "forward:/login.html"; }

    @GetMapping("/product")
    public String product() { return "forward:/product.html"; }

    @GetMapping("/cart")
    public String cart() { return "forward:/cart.html"; }

    @GetMapping("/checkout")
    public String checkout() { return "forward:/checkout.html"; }

    @GetMapping("/confirmation")
    public String confirmation() { return "forward:/confirmation.html"; }
}
