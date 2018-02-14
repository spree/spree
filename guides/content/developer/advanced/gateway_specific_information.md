---
title: Gateway Specific Information
section: advanced
---

## Gateway Specific Information

### AuthorizeNet and AuthorizeNet CIM

The transaction with Authoriet.Net comes in two flavors: One, you pass the 16-digit credit card to authorize.net and obtain a transaction key uniquely identifying that transaction. You can't charge that customer's credit card again. Two, you can use the Customer Information Manager ("CIM") to save a user's credit card attached to their account. AuthorizeNetCIM accomplishes this by obtaining two tokens: one uniquely identifying the user and another uniquely identifying credit card.

In short, if you want to build a feature where a user can "Save this card for later"  you need to use the CIM method when the user has selected to save their credit card and the non-CIM method when the user hasn't.

For your dev, QA, and staging environments we recommend you set up a Authorize.Net sandbox environment, which is available for free to all developers at [http://developer.authorize.net](http://developer.authorize.net).

Please note that in the Spree Admin > Configuration > Payment Methods screen, you will create payment methods for each of the AuthorizeNet and AuthorizeNetCIM objects (probably both).

For both you real business's Authorize.net account and your sandbox, you will generate a "API Login id" and a "Transaction key." In the Spree Payment methods interface, plug the API Login Id into the field marked "LOGIN" and the Transaction Key into the field marked "PASSWORD". (Your Spree::Gateway::AuthorizeNet and Spree::Gateway::AuthorizeNetCIM object can use the same API login id & transaction keys.)

WARNING: If you reset your Authorize.net password (via the web interface), these credentials will be expired and regenerated automatically. However, the old set of credentials will continue to work for a period of 24 hours before they cease working.

Here on the edit Payment Method screen you will also see settings for both "test mode" and a setting for "server." Do not confuse the two settings.

In both the AuthorizeNet and AuthorizeNetCIM objects, the "server" setting must be set to either 'live' (for your real-live authorize.net Production environemnt tied to your business's bank account) or 'test' (for a sandbox account you created on http://developer.authorize.net)

Note that it is additionally possible to set "Test Mode" on _either_ your Live or Sandbox (test) environments. There are four possible use cases for live server/test server and test mode on/off:

Test server with test mode On - Probably redundant, you generally will never need this configuration. If you do have a need for this, you can use a real credit card number or one of the fake numbers (like these [test credit card numbers](https://community.developer.authorize.net/t5/Integration-and-Testing/Test-Credit-Card-Numbers/td-p/7653)) to test for a successful result.

Test server with test mode Off - Probably how you want your dev, QA, and staging servers set up. You can use a real credit card or any of the Authorize.net FAKE (aka "test") credit card numbers to get a successful transaction.

Live server with test mode On - You're going to do this the _very first time_ you ever set up you new Spree store. When Test Mode is ON and your store is live (the  first day you "go live"), you're going to put in a real credit card into the gateway and you will simulate a tranasction on your website. Your credit card will not actually be charged for this transaction, although Authorize.net will return a successful response to your Spree store to simulate what it would be like for a real customer. This will be the final step of verifying that your Authorize.net gateway is working before switching Test Mode to "Off" (thus making yout store ready for business)

Live server with test mode Off - This is how your live, production website operates when the store is in business.

Separated Auth & Capture Warning: If you have a separated authorize event from capture event (in Authorize.net terms this is called an "auth" event and "prior auth capture" event), the Sandbox won't return a transaction ID correctly if Test mode is set to ON. Instead, it will simply return a "0". This will mean that any subsequent "prior auth capture" event will fail because the capture relies on the previously-generated transaction ID. So essentially, if you have a store with a separated auth and capture do not turn Test mode to "On".

(If you have test mode "Off" the Sandbox environment Authorize.net will generate transaction IDs that begin with the number 2)
