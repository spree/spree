---
title: PCI Compliance
section: security
order: 1
---

## Overview

All store owners wishing to process credit card transactions should be familiar with [PCI Compliance](http://en.wikipedia.org/wiki/Pci_compliance). [Spree Gateway Stripe itnegration](https://github.com/spree/spree_gateway) and [Spree Braintree vzero](https://github.com/spree-contrib/spree_braintree_vzero) are PCI-compliant.

## Transmit Exactly Once

Spree uses extreme caution in its handling of credit cards. In production mode, credit card data is transmitted to Spree via SSL. The data is immediately relayed to your chosen payment gateway and then discarded. The credit card data is never stored in the database (not even temporarily) and it exists in memory on the server for only a fraction of a second before it is discarded.

Spree does store the last four digits of the credit card and the expiration month and date. You could easily customize Spree further if you wanted and opt out of storing even that little bit of information.

## 3-D Secure and Strong Customer Authenthication support

[Spree Gateway Stripe itnegration](https://github.com/spree/spree_gateway) supports [Strong Customer Authentication (SCA)](https://stripe.com/en-pl/guides/strong-customer-authentication) out of the box. Remember to use S**tripe Elements** gateway with **Payment Intents** option enabled.

[Spree Braintree vzero](https://github.com/spree-contrib/spree_braintree_vzero) extension supports [3D Secure 2.0](https://developers.braintreepayments.com/guides/3d-secure/overview).
