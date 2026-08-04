/*
 * Shared login/session helper, included on every store page.
 *
 * - Redirects to /login if nobody is signed in.
 * - Renders the signed-in username into the element  #rumUser  (same id, and
 *   therefore the same XPath, on every page) so eG RUM can capture it:
 *
 *       XPath to configure in eG RUM:   //*[@id="rumUser"]
 *       (its text content is the username; it is also in data-rum-user)
 */
(function () {
    var KEY = 'shopUser';
    var path = location.pathname;
    var user = null;
    try { user = localStorage.getItem(KEY); } catch (e) {}

    // Gate every page behind login (the login page itself is exempt).
    if (!user && path !== '/login' && path !== '/login.html') {
        location.replace('/login');
        return;
    }

    function apply() {
        var el = document.getElementById('rumUser');
        if (el && user) {
            el.textContent = user;
            el.setAttribute('data-rum-user', user);
        }
        // If the eG RUM JS API exposes a user-tagging call, wire it here too:
        // if (window.egRum && window.egRum.setUser) window.egRum.setUser(user);
    }

    if (document.readyState !== 'loading') apply();
    else document.addEventListener('DOMContentLoaded', apply);

    window.egLogout = function () {
        try { localStorage.removeItem(KEY); } catch (e) {}
        location.href = '/login';
    };
})();
