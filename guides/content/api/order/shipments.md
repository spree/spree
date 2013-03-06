---
title: Shipments
---

# Shipments API

## Marking a shipment as ready

<%= admin_only %>

To mark a shipment as ready, make a request like this:

    PUT /api/orders/R1234567/shipments/1/ready

You may choose to update shipment attributes with this request as well:

    PUT /api/orders/R1234567/shipments/1/ready?shipment[number]=1234567

### Response

<%= headers 200 %>
<%= json(:shipment) %>

## Marking a shipment as shipped

<%= admin_only %>

To mark a shipment as shipped, make a request like this:

    PUT /api/orders/R1234567/shipments/1/ship

You may choose to update shipment attributes with this request as well:

    PUT /api/orders/R1234567/shipments/1/ship?shipment[number]=1234567

### Response

<%= headers 200 %>
<%= json(:shipment) %>
