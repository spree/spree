## Spree 2.3.0 (unreleased) ##

*   Support existing credit card feature on checkout.

    Checkouts_controller#update now uses the same Order::Checkout#update_from_params
    from spree frontend which help us to remove a lot of duplicated logic. As a
    result of that `payment_source` params must be sent now outsite the `order` key.

    Before you'd send a request like this:

        ```ruby
        api_put :update, :id => order.to_param, :order_token => order.guest_token,
          :order => {
            :payments_attributes => [{ :payment_method_id => @payment_method.id.to_s }],
            :payment_source => { @payment_method.id.to_s => { name: "Spree" } }
          }
        ```

    Now it should look like this:

        ```ruby
        api_put :update, :id => order.to_param, :order_token => order.guest_token,
          :order => {
            :payments_attributes => [{ :payment_method_id => @payment_method.id.to_s }]
          },
          :payment_source => {
            @payment_method.id.to_s => { name: "Spree" }
          }
        ```

    Josh Hepworth and Washington

*   api/orders/show now display credit cards as source under payment

    Washington Luiz

*   refactor the api to use a general importer in core gem.

    Peter Berkenbosch

* Shipment manifests viewed within the context of an order no longer return variant info. The line items for the order already contains this information. #4498

    * Ryan Bigg