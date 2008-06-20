# Payment Gateway

Mixins a payment_gateway method into Spree::BaseController.  Any gateway that is returned is expected to be compatible with Active Merchant.  See <http://activemerchant.org> for details.

## Warning

This is a core extension for Spree.  All core extensions are required in order for Spree to function properly.  There are situations where you may want to replace this extension with your own code.  That is the reason why we implemented this functionality as an extension in the first place.  Disabling or replacing this extension, however, should only be attempted once you have a solid understanding of the Spree internals.

