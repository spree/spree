---
title: Checkouts
---

# Checkouts API

## Introduction

The checkout API functionality can be used to advance an existing order's state. Sending a `PUT` request to `/api/checkouts/ORDER_NUMBER` will advance an order's state or, failing that, report any errors.

The checkout API can also be used to create a new, empty order. Send a `POST` request to `/api/checkouts` in order to accomplish this.

The following sections will walk through creating a new order and advancing an order from its `cart` state to its `complete state.

## Create

To create a new, empty order, make this request:

    POST /api/checkouts


### Response

<%= headers 200 %>
<%= json :order %>

## Address

The newly created order is currently in the `cart` state. After <%= link_to "adding line items", 'line_items' %> to the order, it can be advanced to its next state, `address`, by making this request:

    PUT /api/checkouts/R335381310

### Response

<%= headers 200 %>
<%= json(:order_show_address_state) %>

## Delivery

To advance to the next state, `delivery`, the order will first need both a shipping and billing address.

In order to update the addresses, make this request with the necessary parameters:

    PUT /api/checkouts/R335381310

As an example, here are the required address attributes and how they should be formatted:

<%= json \
  :order => {
    :bill_address_attributes => {
      :firstname  => 'John',
      :lastname   => 'Doe',
      :address1   => '7735 Old Georgetown Road',
      :city       => 'Bethesda',
      :phone      => '3014445002',
      :zipcode    => '20814',
      :state_id   => 1,
      :country_id => 1
    },

    :ship_address_attributes => {
      :firstname  => 'John',
      :lastname   => 'Doe',
      :address1   => '7735 Old Georgetown Road',
      :city       => 'Bethesda',
      :phone      => '3014445002',
      :zipcode    => '20814',
      :state_id   => 1,
      :country_id => 1
    }
  }
%>

### Response

<%= headers 200 %>
<%= json(:order_show_delivery_state) %>

Once valid address information has been submitted, the shipments and shipping rates available for this order will be returned inside a `shipments` key inside the order:

## Payment

To advance to the next state, `payment`, you will need to select a shipping rate for the order. These were returned when transitioning to the `delivery` step. If you need want to see them again, make the following request:

    GET /api/orders/R335381310

If the order already has a shipping rate selected, you can advance it to the `payment` state by making this request:

    PUT /api/checkouts/R335381310

If the order doesn't have an assigned shipping rate, make the following request to select one and advance the order's state:

    PUT /api/checkouts/R366605801?order[shipments_attributes][0]
    [selected_shipping_rate_id]=1&order[shipments_attributes][0][id]=1

**NOTE**: Please ensure you select a shipping rate for each shipment in the order. In the request above, the `selected_shipping_rate_id` should be the id of the shipping rate you want to use and the `id` should be the id of the shipment you are choosing this shipping rate for.

### Response

<%= headers 201 %>
<%= json(:order_show_payment_state) %>

## Confirm

To advance to the next state, `confirm`, the order will need to have a payment.

If the order already has a payment, you can advance it to the `confirm` state by making this request:

    PUT /api/checkouts/R335381310

If the order doesn't have an assigned payment method, make the following request to setup a payment method and advance the order:

    PUT /api/checkouts/R335381310?order[payments_attributes][][payment_method_id]=1

For more information on payments, view the <%= link_to "payments documentation",'payments' %>.

### Response

<%= headers 200 %>
<%= json(:order_show_confirm_state) %>

## Complete

Now the order is ready to be advanced to the final state, `complete`. To accomplish this, make this request:

    PUT /api/checkouts/R335381310

### Response

<%= headers 200 %>
<%= json (:order_show_complete_state) %>
