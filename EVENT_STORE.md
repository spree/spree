## SPREE EVENT STORE

### Scope

##### CART ACTIONS:
* AddToCart —> LineItem
* RemoveFromCart —> LineItem
* EmptyCart —> EmptyOrder
* ApplyCouponCode —> Promotion
##### ADDRESS ACTIONS:
* AddBillingAddress —> Address ( type: billing )
* RemoveBillingAddress —> Address ( type: billing )
* AddShippingAddress —> Address ( type: shipping )
* RemoveShippingAddress —> Address ( type: shipping )
* EditBillingAddress —> Address ( type: billing )
* EditShippingAddress —> Address ( type: shipping )
##### SHIPPING ACTIONS:
* ChooseShippingMethod —> ShippingMethod
##### ORDER ACTIONS:
* OrderPayment —> Payment
* OrderComplete —> Order
* OrderCancelled —> Order
* OrderShipped —> Order

### INSTALLATION 

Installation by adding flag `install_event_store=true`

Example:

```ruby
bin/rails g spree:install --user_class=Spree::User --install_event_store=true
```

### CONFIGURATION

Configuration file in: `config/initializers/spree_event_store.rb`
