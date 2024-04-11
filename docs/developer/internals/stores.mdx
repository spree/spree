---
title: Stores
section: internals
order: 0
---

# Stores

## Overview

The `Spree::Store` model is the center of the Spree ecosystem. Each Spree installation can have multiple Stores. Each Store operates on a different domain or subdomain, eg.

* Store A, `us.example.com`
* Store B, `eu.example.com`
* Store C, `another-brand.com`

![](../.gitbook/assets/mulit\_store\_978x2.png)

## `current_store` method

All Spree controllers or any other controllers that include [Spree::Core::ControllerHelpers::Store](https://github.com/spree/spree/blob/master/core/lib/spree/core/controller\_helpers/store.rb) have access to the `current_store` method which returns the currently in selected `Spree::Store` object.

All parts of Spree (API v1, API v2, Storefront, Admin Panel) have this implemented. This method is also available in views and JSON serializers.

Under the hood `current_store` calls [Spree::Stores::FindCurrent.new(url: url).execute](https://github.com/spree/spree/blob/master/core/app/finders/spree/stores/find\_current.rb).

## Default Store

If the system cannot find any Store that matches the current URL it will fall back to the Default Store.

You can set the default Store in `Admin Panel -> Configurations -> Store` or via Rails console:

```ruby
Spree::Store.find(2).update(default: true)
```

To get the default store in your code or rails console type:

```ruby
Spree::Store.default
```

## Localization and Currency

Each Store can have multiple locales and currencies. This configuration is stored in Store model attributes:

* `default_currency`- this is the default currency that will be pre-selected when visiting the store the first time, eg. `USD`
* `supported_currencies` - if there is more than one supported currency, visitors will be able to choose which currency they would like to browse your store in, eg. `USD`, `CAD`, etc.
* `default_locale` - this is the default locale/language which will be pre-selected when visiting the store the first time, eg. `en`
* `supported_locales`, if there is more than one supported locale, visitors will be able to choose which locale they would like to browse your store in, eg. `en`, `fr`, etc. Locales are available upon installing [Spree I18n](https://github.com/spree-contrib/spree\_i18n)

As of version 4.6, the `Store` resource allows for translating many of its fields. Translations are enabled when selecting more than one locale in `supported_locales`. The following fields are translatable:

* `name`
* `meta_description`
* `meta_keywords`
* `seo_title`
* `facebook`
* `twitter`
* `instagram`
* `customer_support_email`
* `description`
* `address`
* `contact_phone`
* `new_order_notifications_email`

Read more about how resource translations work in [Internationalization](../customization/i18n.md#resource-translations).

## Checkout configuration

Each Store can be configured to ship to only selected countries. This is achieved via the `checkout_zone_id` attribute which holds the ID of the selected [Zone record](shipments.md#zones).

Available Shipping Methods on the Checkout are determined based on the [Zone and Shipping Methods configuration](shipments.md).

This will also have an effect on what [Shipping / Billing Addresses](addresses.md) user can add/ select during Checkout. Only Addresses from Countries or States available in the selected Zone can be used and will be visible in the User's Address Book.

## Store resources

| Resource                                          | Relationship                                                                                                                               |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| [**Order**](orders.md)                            | One Order belongs to one Store                                                                                                             |
| [**Product**](products.md)                        | One Product can be associated with many Store(s), you can pick and choose in which Store(s) each Product will be available                 |
| [**Payment Method**](payments.md)                 | One Payment Method can be associated with many Store(s), you can select in which Stores given Payment Method will be available on Checkout |
| **Store Credit**                                  | One Store Credit belongs to and can be used in one Store                                                                                   |
| **CMS Page**                                      | One Page belongs to one Store                                                                                                              |
| **Navigation Menu**                               | One Menu belongs to one Store                                                                                                              |
| [**Taxonomy**](products.md#taxons-and-taxonomies) | One Taxonomy belongs to one Store                                                                                                          |
| [**Promotion**](promotions.md)                    | One Promotion can be associated with multiple Stores                                                                                       |
