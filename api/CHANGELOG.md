## Spree 2.0.8 (unreleased) ##

* When line items are added after the delivery state, the shipments are now recreated. #3914

    Washington Luiz

* State names are now persisted on addresses when using `ensure_state_from_api`, even if the state does not exist as a `Spree::State`. e976a3bbd603ea981499f440fa69f2e6d0d930d7

    Washington Luiz

* Times are now returned with millisecond precision. (Note: this patch is not in the 2-1-stable or master branches because Rails 4 does this by default.)

    Washington Luiz
    