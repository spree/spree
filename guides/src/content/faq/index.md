---
title: FAQ
---

If you can't find an answer to your question, feel free to ask us [here](http://slack.spreecommerce.com/)

## Payments

**Q: Is there any way to use Storefront API with Stripe Element?**

A: Yes, you need to implement Stripe Elements in your custom frontend and use API endpoints. Get a Stripe Elements Spree payment gateway ID from [here](https://stoplight.io/p/docs/gh/spree/spree/api/docs/v2/storefront/index.yaml/paths/~1api~1v2~1storefront~1checkout~1payment_methods/get?srn=gh/spree/spree/api/docs/v2/storefront/index.yaml/paths/~1api~1v2~1storefront~1checkout~1payment_methods/get&group=master).
You'll also have to [update checkout](https://stoplight.io/p/docs/gh/spree/spree/api/docs/v2/storefront/index.yaml/paths/~1api~1v2~1storefront~1checkout/patch?srn=gh/spree/spree/api/docs/v2/storefront/index.yaml/paths/~1api~1v2~1storefront~1checkout/patch&group=master#add-payment-sources) with the proper ID.

**Q: Is there any open source extension to implement subscriptions?**

A: Unfortunately not. We've found out that every single subscription project was different. We also wanted to stay provider agnostic.

**Q: To build a custom gateway, should I add and use app/models/spree/gateway instead of building an entire new extension?**

A: Add a new class in app/models/spree/gateway in your project.

**Q: What is the correct gem to use for integrating Spree v3.6 with PayPal?**

A: The correct gem can be found [here](https://github.com/spree-contrib/spree_braintree_vzero).

**Q: Are there any guides on how to implement subscriptions?**

A: Depending on the project, we integrate one of these:
* [Chargify](https://www.chargify.com/)
* [Chargebee](https://www.chargebee.com/)
* [Stripe](https://www.stripe.com/gb/billing/)

If requirements are unusual, require a custom job or only some payment processors are accepted, we implement subscriptions from scratch.

**Q: Do spree_braintree_vzero and better_spree_paypal_express support IPN?**

A: None of those support IPN.

**Q: Is it possible to use Spree as an API only and use checkout from outside of API?**

A: Yes, you can use the homepage, product listings and product detail pages as a JS app communicating with the Spree backend using APIs or even embedded on WordPress pages with only checkout on Spree pages.

**Q: Is there a way to disable refund and void on the backend?**

A: Yes. By overriding and checking if this gateway is used. If yes, do not render an option for refunds. It's not the best solution, but it will work. For more information, please refer to [this link](https://guides.spreecommerce.org/developer/customization/view.html).

**Q: What is "@order.next!" And where is method "next!" declared?**

A: This method is inherited from state machines gem. More on this topic [here](https://guides.spreecommerce.org/developer/core/orders.html#the-order-state-machine).

**Q: Is there a guide for building a custom gateway with an API endpoint?**

A: Yes, feel free to take a look at [this guide](https://guides.spreecommerce.org/developer/core/payments.html#adding-your-custom-gateway).

**Q: How to trigger a refund on the backend?**

A: Please refer to the [following guide](https://guides.spreecommerce.org/user/orders/returning_orders.html).

**Q: What is the best way of handling the "Payments at home" method?**

A: "Check" payment method will be sufficient for this case.

## Marketplaces

**Q: I want to use Spree as a drop shipping platform. Do you know any tutorials or advice to make the system fit this purpose?**

A: Yes, feel free to take a look at [this repository](https://github.com/spree-contrib/spree_multi_vendor).

**Q: Does Spree support multiple separated shops?**

A: Yes, it does. Multi-vendor has been integrated into the core Spree.

## Configuration

**Q: Where should fonts be installed?**

A: Feel free to take a look at [this link](https://coderwall.com/p/v5c8kq/web-fonts-and-rails-asset-pipeline).

**Q: What kind of system requirement is recommended to run Spree?**

A: For development/staging, Heroku 1x dyno (0.5 GB RAM) would be sufficient.

**Q: What's the best possible way for customizing existing spree checkout into single page checkout in Spree 4.1?**

A: A solution to that can be found [here](https://guides.spreecommerce.org/api/v2/storefront).

**Q: Does Spree allow for wholesale and detailed pricing?**

A: Yes, feel free to take a look at [this link](https://github.com/spree-contrib/spree_volume_pricing).

**Q: Does Spree support more than one promotion per order?**

A: Yes, more than one promotion can be applied; e.g. Free Shipping based on Cart total and a discount coupon.

**Q: How is it possible to swap an .svg logo?**

A: You can find the solution [here](https://guides.spreecommerce.org/developer/customization/view.html#switch-storefront-logo).

## API & Headless

**Q: Is there any mobile app to handle the Spree backend?**

A: There is a storefront API that can be used to communicate with the Spree backend. Feel free to take a look at [this guide](https://guides.spreecommerce.org/api/v2/).

**Q: Is it a good idea to extend RoR API with the spree_api gem?**

A: Spree is combined with the current RoR codebase out of the box.

**Q: Can Microsoft SQL Server be used as a database for Spree eCommerce applications?**

A: Theoretically, it is possible; feel free to take a look at [this link](https://github.com/rails-sqlserver/activerecord-sqlserver-adapter).

**Q: Is there a default React frontend for Spree?**

A: It's quite easy to build one with the help of [Spree storefront API](https://github.com/spree/spree-storefront-api-v2-js-sdk), but there is no default.

## Shipping

**Q: How should I activate COD (Cash on Delivery)?**

A: You can use the Check payment method and rename it Cash on Delivery.

**Q: Are there any recommended shipping extensions?**

A: Yes, please go to [spreecommerce website](https://spreecommerce.org), choose the integrations section, and pick "Shipping".

## Products

**Q: Does Spree 4.1 include digital products?**

A: There is an extension for it in spree_contrib.

**Q: How can I show products for a certain date range?**

A: By default, in Spree's storefront, we only show available products, that is products in a date range set between the "Available on" date and 'Discontinued on' date. More on this subject can be found [here](https://guides.spreecommerce.org/developer/core/products.html).

**Q: I'm getting a "can't find record (...)" errors for taxonomies.**

A: Try loading samples - bundle exec rake spree_sample:load

**Q: What is the recommendation for binding a product to a specific store in Spree 3.7?**

A: Using the 'default_currency' should take care of that. In Spree, whenever a store has a 'default_currency' set to, for example USD, Users will be able to see only the products which have prices in that currency. To make it happen, you will need to install the spree_multi_currency gem. For newer Spree versions, starting from 4.2, this will be possible with just the core Spree itself.

**Q: How to make products stay hidden or displayed based on the approval/rejection of an admin?**

A: The first option is to use the "Available on" and "Discontinued on" dates, you can read about it more in [this guide](https://guides.spreecommerce.org/developer/core/products.html). The second option is to add custom product properties such as: new, published, rejected, hidden. You can read about it more in [this guide](https://guides.spreecommerce.org/developer/core/products.html#product-properties).

**Q: I'm having issues understanding variants vs master variants logic.**

A: Please look into [this guide](https://guides.spreecommerce.org/developer/core/products.html#master-variants).

## Hosting

**Q: Is there any good guide on how to deploy the application to production on Elastic Beanstalk apart from Heroku?**

A: Yes, feel free to take a look at: [Code with Jason](https://www.codewithjason.com/deploy-ruby-rails-application-aws-elastic-beanstalk/).

**Q: Heroku is not what I am looking for to deploy Spree to a VPS. Are there any alternatives?**

A: Yes, take a look at [Capistrano](https://capistranorb.com/).

## Other

**Q: Is there any way to login to application without the frontend gem?**

A: Yes, take a look at [this link](https://guides.spreecommerce.org/developer/customization/authentication.html).
Also, you can use spree_auth_devise gem without spree_frontend since v3.5. Please refer to [this link](https://github.com/spree/spree_auth_devise/releases/tag/v3.5.0).

**Q: Is there some themes/templates for a marketplace, so I don't have to do the design work from scratch?**

A: Yes, feel free to look at [New Spree UX](https://bit.ly/new-spree-ux) and, as an example [this article](https://sparksolutions.co/covid-19-response-well-delivered-online-store-for-employees-only/).

**Q: Is Spree a good solution to create a mobile marketplace C2C?**

A: Yes, but with some custom development. Take a look at [this article](https://spreecommerce.org/building-a-p2p-marketplace-on-spree-commerce-for-the-sharing-renting-swapping-economy/).

**Q: If using Rails 6, what conventions of using the JavaScript directory should we use? Inside the assets folder as it was or outside as is now Rails 6 convention?**

A: Spree creo assets are still being kept in the *app/assets/javascripts*. For all the custom project specific assets, we usually use webpacker and JavaScript packs. You can easily combine both.

**Q: Is there a document on how to integrate spree_analytics_trackers with Facebook pixel?**

A: Yes, feel free to look at this [document](https://segment.com/docs/connections/destinations/catalog/facebook-pixel/).

**Q: I would like to know how ActiveMerchant works on Spree. Is there any document for this purpose?**

A: Yes, feel free to take a look at [this link](https://guides.spreecommerce.org/developer/core/payments.html). Also, as a reference, please check the [Stripe gateway source code](https://github.com/spree/spree_gateway/blob/master/app/models/spree/gateway/stripe_gateway.rb#L31).

**Q: Since active_shipping no longer supports the UPS API, is there any good library that integrates well with Spree and uses the UPS API?**

A: Yes, feel free to take a look at [this repository](https://github.com/ShopFelixGray/spree_easy_post).

**Q: Is there a gem on the spree frontend that can be used for marketing conversion?**

A: Yes, please refer to [this link](https://github.com/spree-contrib/spree_analytics_trackers).

**Q: Can you authenticate users with open-id?**

A: Yes, take a look at [this link](https://github.com/m0n9oose/omniauth_openid_connect) and [this link](https://github.com/spree-contrib/spree_social).

**Q: Can I migrate Spree 3.7 (Rails 5.2) to Spree 4 (Rails 6) and keep Boostrap 3 at the same time?**

A: Yes, you can keep your current design. However, please remember to copy over all your view/assets(javascript/css) and keep them in your application. Spree won't try to override them if you have your own copies.

**Q: Where can I find Spree license?**

A: You can find the Spree license [here](https://github.com/spree/spree/blob/master/license.md).

**Q: Where can I find Spree release notes?**

A: All Spree release notes can be found [here](https://guides.spreecommerce.org/release_notes).

**Q: What gem handles the related products carousel?**

A: Related products carousel are handled by spree_related_products gem.

**Q: Is the cart destroyed after a successful checkout?**

A: No, the cart is not destroyed, but it won't be available in the /cart endpoint.

**Q: Is a new instance of the Cart with a different number attribute created after a succesfful checkout and adding items to the Cart?**

A: The process has to be started again: create another cart by posting to /cart endpoint.

**Q: Is there a guide about managing application logic?**

A: Yes, please refer to [this guide](https://upsidelab.io/blog/rails-spree-command-pattern/).

**Q: Is there a documentation on how to customize assets?**

A: Yes, please refer to [this document](https://guides.spreecommerce.org/developer/customization/storefront.html) and [this example](https://bit.ly/new-spree-ux).

**Q: Where can I find Spree 4 themes?**

A: You can customize it. Everything (examples, customization, tutorial, docs) can be found [here](https://spreecommerce.org/spree-commerce-demo-explainer).

**Q: In a multi-vendor scenario, does Spree support a Single Detail Page with a single Buy Box algo?**

A: That's currently not possible out of the box; this would require some customizations.

**Q: How to optimize Active Storage?**

A: See [this article](https://https://tech.kartenmacherei.de/scaling-activestorage-21e962f708d7). Also adding S3, cache store and lazy loading (out of the box in Spree 4.1) to your rails application greatly helps with serving images via Active Storage.

**Q: How to avoid the "The resource you were looking for could not be found" error when trying to send an API request to /cart?**

A: The cart needs to be created first before any API requests.

**Q: Is 8GB RAM enough for running Spree efficiently?**

A: 8GB is definitely enough; however, the results may vary depending on the number of SKU's and the size of the database.

**Q: Is Ruby 2.7 supported?**

A: No, Ruby 2.7 isn't supported yet by Rails and Spree. For now, please use either 2.5 or 2.6, both will work just fine.
