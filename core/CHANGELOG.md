## Spree 2.2.1 (unreleased) ##

*   A user_id and payment_method_id column were added to CreditCard. By default
    both are set when initializing the payment source (via Payment object). That
    should help improving payment profiles control for both customers and store
    owners. A Core::UserPaymentSource module was added to exemplify what should
    be added to the user class to make better use of that feature.

    Washington Luiz

*   refactor the api to use a general importer in `lib/spree/importer/order.rb`

    Peter Berkenbosch

*   Ensure transition to payment processing state happens outside transaction.

    Chris Salzberg
