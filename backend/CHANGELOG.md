## Spree Edge ##

* Allow errors from customer details to be displayed. Previously any update to the customer details, successful or not, 
would flash a success message. This resolves that by allowing errors to be displayed should they happen. By default there
is no state past complete so there is no need to attempt next transition once the state is complete.
