## Spree 2.3.0 (unreleased) ##

### Preferences Refactoring

Preferences defined on ActiveRecord objects are now stored on the same table.
This is done by adding a preferences column which is serialized via
ActiveRecord::Base.serialize.

```
> Spree::Calculator.first
=> #<Spree::Calculator::Shipping::FlatRate id: 1,
                                           type: "Spree::Calculator::Shipping::FlatRate",
                                           calculable_id: 1,
                                           calculable_type: "Spree::ShippingMethod",
                                           created_at: "2014-03-13 01:38:27",
                                           updated_at: "2014-03-13 01:38:28",
                                           preferences: {:amount=>5.0, :currency=>"USD"}>
```

Records now need to be saved for modified preferences to be persisted.
Assigning `calculator.preferred_amount = 10` will not update the database
record until `calculator.save` is called.

A migration will move existing preferences onto the new column.
