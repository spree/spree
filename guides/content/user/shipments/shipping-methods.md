---
title: Shipping Methods
---

## Introduction

Spree uses a very flexible and effective system to calculate shipping, accommodating the full range of shipment pricing: from simple flat rate to complex product-type and weight-dependent calculations. This guide explains how Spree represents shipping options, how it calculates expected costs, and how you can configure the system with your own shipping methods.

To properly leverage Spree’s shipping system’s flexibility you must understand a few key concepts:

* Shipping Methods
* Zones
* Shipping Categories
* Calculators (through Shipping Rates)

## Shipping Methods

Shipping methods are the services used to send the product. For example:

* UPS Ground
* UPS One Day
* FedEx 2Day
* FedEx Overnight
* DHL International

Each shipping method is only applicable to a specific Zone. For example, you wouldn’t be able to get a package delivered internationally using a domestic-only shipping method. You can’t ship from Dallas, USA to Rio de Janeiro, Brazil using UPS Ground (a US-only carrier).

## Zones

Zones serve as a mechanism for grouping geographic areas together into a single entity. A zone is comprised of many different "zone members", which can either be a set of countries or a set of states.

The Shipping Address entered during checkout will define the zone the customer is in and limit the Shipping Methods available to him.

## Shipping Categories

Shipping Categories are useful if you sell products whose shipping pricing vary depending on the type of product (TVs and Mugs, for instance). 

Some examples of Shipping Categories would be:

* Light (for lightweight items like stickers)
* Regular
* Heavy (for items over a certain weight)

When you create a new product, you choose which shipping category you would like to associate with the product. During checkout, the shipping categories of the products in your order will determine which calculator will be used to price its shipping for each Shipping Method.

## Calculators

A Calculator is the component responsible for calculating the shipping price for each available Shipping Method.

Spree ships with 4 default Calculators:

* Flat rate (per order)
* Flat rate (per item/product)
* Flat percent
* Flexible rate
* Price sack

Flexible rate is defined as a flat rate for the first product, plus a different flat rate for each additional product.

You can define your own calculator if you have more complex needs. In that case, check out the [Calculators Guide](developer/calculators.html).

