---
title: "Addresses"
section: core
---

## Address

The `Address` model in the `spree` gem is used to track address information, mainly for orders. Address information can also be tied to the `Spree::User` objects which come from the `spree_auth_devise` extension.

Addresses have the following attributes:

* `firstname`: The first name for the person at this address.
* `lastname`: The last name for the person at this address.
* `address1`: The address's first line.
* `address2`: The address's second line.
* `city`: The city where the address is.
* `zipcode`: The postal code.
* `phone`: The phone number.
* `state_name`: The name for the state.
* `alternative_phone`: The alternative phone number.
* `company`: A company name.

Addresses can also link to countries and states. An address must always link to a `Spree::Country` object. It can optionally link to a `Spree::State` object, but only in the cases where the related country has no states listed. In that case, the state information is still required, and is kept within the `state_name` field on the address record. An easy way to get the state information for the address is to call `state_text` on that object.

## Zones

When an order's address is linked to a country or a state, that can ultimately affect different features of the order, including shipping availability and taxation. The way these effects work is through zones.

A zone is comprised of many different "zone members", which can either be a set of countries or a set of states.

Every order has a "tax zone", which indicates if a user should or shouldn't be taxed when placing an order. For more information, please see the [Taxation](taxation) guide.

In addition to tax zones, orders also have shipping methods. These are provided to the user based on their address information, and once selected lock in how an order is going to be shipped to that user. For more information, please see the [Shipments](shipments) guide.

## Countries

Countries within Spree are used as a container for states. Countries can be zone members, and also link to an address. The difference between one country and another on an address record can determine which tax rates and shipping methods are used for the order.

## States

States within Spree are used to scope address data slightly more than country. States are useful for tax purposes, as different states in a country may impose different tax rates on different products. In addition to this, different states may cause different tax rates and shipping methods to be used for an order, similar to how countries affect it also.
