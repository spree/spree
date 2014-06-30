## Spree 2.3.0 (unreleased) ##

*   The api key that was previously placed in the dom for ajax requests has been
    removed since the api now uses the session to authenticate the user.

*   Mostly inspired by Jeff Squires extension spree_reuse_credit card, checkout
    now can remember user credit card info. Make sure your user model responds
    to a `payment_sources` method and customers will be able to reuse their
    credit card info.

    Washington Luiz

*   Use settings from current_store instead of Spree::Config

    Jeff Dutil, John Hawthorn, and Washington Luiz
