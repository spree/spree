---
title: "Core | Models | Payment"
section: core
---

# Payment

The `Payment` model in Spree tracks payments against
<%= link_to "Orders", :orders %>. Payments relate to a `source` which
indicates how the payment was made, and a
[Payment Method](/core/developer/models/payment_method), indicating the payment
processor used for processing this payment.

A payment can go through many different states, as illustrated below.

![Payment flow](../images/developer/core/payment_flow.jpg)
