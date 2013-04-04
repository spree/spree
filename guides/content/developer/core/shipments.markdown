---
title: "Shipments"
---

## Overview

This guide explains how Spree represents shipping options and how it calculates
expected costs, and shows how you can configure the system with your own shipping
methods.
After reading it you should know:

* how shipments and shipping are implemented in Spree
* how to specify your shipping structure
* how split shipments work
* how to configure products for special shipping treatment
* how to capture shipping instructions

Spree uses a very flexible and effective system to calculate shipping, accomodating
the full range of shippment pricing: from simple flat rate to complex product-type and
weight dependent calculations.

Explaining each piece separately and how they fit together can be a cumbersome task.
Fortunately, using a few simple examples makes it much easier to grasp.

In that spirit, the examples are shown first in this guide.

## Examples

### Simple Setup

Consider you sell t-shirts to US and Europe and ship from a single location

And you work with 2 deliverers:

* USPS Ground (to US)
* FedEx (to EU)

And their pricing is as follow:

* USPS charges $5 for one t-shirt and $2 for each additional one
* FedEx charges $10 each, regardless of the quantity

To achieve this setup you need the following configuration:

* Shipping Categories: All your products are the same, so you don't need any.
* 2 Shipping Methods (Configuration->Shipping Methods):
* 1 Stock Location: You are shipping all items from the same location, so you can use the default.

|Name|Zone|Calculator|
|USPS Ground|US|Flexi Rate($5,$2)|
|FedEx|EU_VAT|FlatRate-per-item($10)|

### Advanced Setup

Consider you sell products to a single zone (US) and you ship from 2 locations (Stock Locations):

* New York
* Los Angeles

And you work with 3 deliverers (Shipping Methods):

* FedEx
* DHL
* US postal service.

And your products can be classified into 3 Shipping Categories:

* Light
* Regular
* Heavy

And their pricing is as follow:

FedEx charges:

* $10 for all light items regardles of how many you have
* $2 per regular item
* $20 for first heavy item and $15 for each next one.

DHL charges:

* $5 per item if it's light or regular
* $50 per item if it's heavy.

To achieve this setup you need the following configuration:

* 4 Shipping Categories: Default, light, regular and heavy
* 3 Shipping Methods (Configuration->Shipping Methods): FedEx, DHL, USPS
* 2 Stock Location (Configuration->Stock Locations): New York, Los Angeles


|S. Category / S. Method|DHL|FedEx|USPS|
|Default|Per Item ($5)|-|Weight Bucket|
|Light|-|Flat Rate ($10)|-|
|Regular|-|Per Item ($2)|-|
|Heavy|Per Item ($50)|Flexi Rate($20,$15)|-|

## Design & Functionality

To properly leverage Spree's shipping system's flexibility you must
understand a few key concepts:

* Shipping Methods
* Zones
* Shipping Categories
* Calculators (through Shipping Rates)

### Shipping Methods

Shipping methods are the actual services used to send the product.
For example:

* UPS Ground
* UPS One Day
* FedEx 2Day
* FedEx Overnight
* DHL International

Each shipping method is only applicable to a specific Zone as, for example, you can't ship internationally using a local postal service.

i.e. you can't ship from Dallas, USA to Rio de Janeiro, Brazil using UPS Ground.

If you are using shipping categories these can be used to qualify or disqualify a given shipping method.

## Shipping Methods


## Split Shipments

![image](http://i6.minus.com/ibrAmiN2MBxEFh.png)

### Creating Proposed Shipments

This section steps through the basics of what is involved in determining shipments for an order. There are a lot of pieces that make up this process. They are explained in detail in the [The Components of Split Shipments](#) section of this guide.

The process of determining shipments for an order is triggered by calling `#create_proposed_shipments` on an order object while transitioning to the delivery step during a checkout. This process will first delete any existing shipments for an order and then determine the possible shipments available for that order.

This process is triggered by a call to `Spree::Stock::Coordinator.new(@order).packages`. This will return an array of packages. In order to determine which items belong in which package when they are being built, Spree uses an object called a splitter, described in more detail [below](#).

After obtaining the array of available packages, they are converted to shipments on the order object. Shipping rates are determined and inventory units are created during this process as well.

At this point, the checkout process can continue to the delivery step.

## The Components of Split Shipments

### The Coordinator

The `Spree::Stock::Coordinator` is the starting point when determining shipments when calling `#create_proposed_shipments` on an order. Its job is to go through each `StockLocation` available and determine what can be shipped from that location.

The `Spree::Stock::Coordinator` will ultimately return an array of packages which can then be easily converted into shipments for an order by calling `#to_shipment` on them.

### The Packer

A `Spree::Stock::Packer` object is an important part of the `#create_proposed_shipments` process. Its job is to determine possible packages for a given StockLocation and order. It uses rules defined in classes known as `Splitters` to determine what packages can be shipped from a StockLocation.

For example, we may have two splitters for a stock location. One splitter has a rule that any order weighing more than 50lbs should be shipped in a separate package from items weighing less. Our other splitter is a catch all for any item weighing less than 50lbs. So, given one item in an order weighing 60lbs and two items weighing less, the Packer would use the rules defined in our splitters to come up with two separate packages: one containing the single 60lb item, the other containing our other two items.

#### Custom Splitters

Note that splitters can be customized and creating your own can be done with relative ease. By inheriting from `Spree::Stock::Splitter::Base`, you can create your own splitter.

For an example of a simple splitter, take a look at Spree's [weight based splitter](https://github.com/spree/spree/blob/235e470b242225d7c75c7c4c4c033ee3d739bb36/core/app/models/spree/stock/splitter/weight.rb). THis splitter pulls items with a weight greater than 150 into their own shipment.

### The Prioritizer

A `Spree::Stock::Prioritizer` object will decide which Stock Location should ship which package from an order. The prioritizer will attempt to come up with the best shipping situation available to the user.

### The Estimator

The `Spree::Stock::Estimator` loops through the packages created by the packer and attaches shipping rates to them.

## Stock Management

### Stock Locations

Stock Locations are the locations where your inventory is shipped from. Each stock location has many stock items and stock movements.

Stock Locations are created in the admin interface (Configuration → Stock Locations). Note that a stock item will be added to the newly created stock location for each variant in your application.

### Stock Items

Stock Items represent the inventory at a stock location for a specific variant. Stock item count on hand can be increased or decreased by creating stock movements.

***
Note: Stock items are created automatically for each stock location you have. You don't need to manage these manually.
***

!!!
**Count On Hand** is no longer an attribute on variants. It has been moved to stock items, as those are now used for inventory management.
!!!

### Stock Movements

![image](http://i.minus.com/iboTuJLZLrINnM.png)

Stock movements allow you to mange the inventory of a stock item for a stock location. Stock movements are created in the admin interface by first navigating to the product you want to manage. Then, follow the **Stock Management** link in the sidebar.

As shown in the image above, you can increase or decrease the count on hand available for a variant at a stock location. To increase the count on hand, make a stock movement with a positive quantity. To decrease the count on hand, make a stock movement with a negative quantity.




