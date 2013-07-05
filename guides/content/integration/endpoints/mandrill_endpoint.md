---
title: Mandrill Endpoint
---

## Overview

[Mandrill](http://mandrill.com/) is a transactional email platform that you can use to automatically process your store's emails through the Spree Integrator. Mandrill could be called on any time you needed to, for example:

* confirm to a user that you have received their order,
* notify a user that their order was canceled, or
* send shipment confirmation to a customer.

## Requirements

In order to configure and use the mandrill_endpoint, you will need to first have:

* an account on Mandrill,
* an API token from that account, and
* templates set up in your Mandrill account

## Service Requests

There are message types that the mandrill_endpoint can respond to (incoming), and those that it can, in turn, generate (outgoing). A Service Request is the sequence of actions the endpoint takes when the Integrator sends it a Message.

### Order Confirmation

When the mandrill_endpoint receives a validly-formatted Message to the `/order_confirmation` URL, it passes the order information on to Mandrill's API. Mandrill then sends an email using its matching stored [template](#template) to the user, confirming to them that their order was received.

### Order Cancellation

TODO: Is this the correct scenario?
If a user or an admin cancels an existing order, the store should send a JSON message with the relevant data to the `/order_cancellation` URL. The end point will transmit a message to Mandrill, which then sends an email to the user, confirming that the order was canceled.

### Shipment Confirmation

After an order moves to the `shipped` order state, the store should send notice to the mandrill_endpoint's, via the integration's `/shipment_confirmation` URL, with the relevant order and shipment data. The endpoint will then instruct Mandrill to email the customer, notifying them that the order is en route.

## Configuration

TODO: Elaborate when we finalize the connector.

### Name

### Keys

#### api_key

#### from

#### subject

#### template

### Parameters

### Url

### Token

### Event Keys

### Event Details

### Filters

### Retries