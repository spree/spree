---
title: Shipments
---

# Shipments API

## Create

<%= admin_only %>

The following attributes are required when creating a shipment:

- order_id
- stock_location_id
- variant_id

To create a shipment, make a request like this:

```text
POST /api/orders/R1234567/shipments```

The `order_id` is the number of the order to create a shipment for and is provided as part of the URL string as shown above. The shipment will be created at the selected stock location and include the variant selected.

Assuming in this instance that you want to create a shipment with a stock_location_id of `1` and a variant_id of `10` for order `R1234567`, send through the parameters like this:

<%= json \
  :order_id => 123456,
  :stock_location_id => 1,
  :variant_id => 10
 %>

### Response

<%= headers 200 %>
<%= json(:shipment) %>

## Update

<%= admin_only %>

To update a shipment, make a request like this:

```text
PUT /api/orders/R1234567/shipments/1```

To update shipment information, use parameters like this:

<%= json \
 :shipment => {
   :number=>"12345",
   :tracking=>"TRK9000"
 } %>

### Parameters

unlock
: When set to `yes`, the shipment's adjustment will be recalculated.

### Response

<%= headers 200 %>
<%= json(:shipment) %>

## Ready

<%= admin_only %>

To mark a shipment as ready, make a request like this:

    PUT /api/orders/R1234567/shipments/1/ready

You may choose to update shipment attributes with this request as well:

    PUT /api/orders/R1234567/shipments/1/ready?shipment[number]=1234567

### Response

<%= headers 200 %>
<%= json(:shipment) %>

## Ship

<%= admin_only %>

To mark a shipment as shipped, make a request like this:

    PUT /api/orders/R1234567/shipments/1/ship

You may choose to update shipment attributes with this request as well:

    PUT /api/orders/R1234567/shipments/1/ship?shipment[number]=1234567

### Response

<%= headers 200 %>
<%= json(:shipment) %>

## Add Variant

<%= admin_only %>

To add a variant to a shipment, make a request like this:

    PUT /api/orders/R1234567/shipments/1/add?variant_id=1&quantity=1

### Response

<%= headers 200 %>
<%= json(:shipment) %>

## Remove Variant

<%= admin_only %>

To remove a variant from a shipment, make a request like this:

    PUT /api/orders/R1234567/shipments/1/remove?variant_id=1&quantity=1

### Response

<%= headers 200 %>
<%= json(:shipment) %>
