---
title: Payment States
---

## Introduction

When an order is initiated for a customer purchase a payment is created in the Spree system. Every payment is assigned a unique, 8-character identifier. This is used when sending the payment details to the payment processor and helps to prevent payment gateways from mistakenly reporting duplicate payments. 

## Payment States

A payment goes through various states while being processed. The possible states are:

* **checkout** - The checkout has not been completed.
* **processing** - The payment is being processed.
* **pending** - The payment has been processed but is not yet complete (ex. authorized but not captured).
* **failed** - The payment was rejected (ex. credit card was declined).
* **void** - The payment should not be applied against the order.
* **completed** -  The payment is completed. Only payments in this state count against the order total.

A payment does not necessarily go through each of these states in sequential order as illustrated below:

![Payments Flow](/images/developer/core/payment_flow.jpg)

You can look up the payment states for a particular order by going to the Admin Dashboard and clicking on the **Orders** tab. Find the order you want to look up and click on it. Once you have the order details pulled up, click on the **Payments** link.

![Payment Look Up](/images/developer/core/payments_look_up.jpg)

The details for the payment will appear. The **Payment State** column will display one of the payment states listed above. 

![Payment Details](/images/developer/core/payments_look_up.jpg)