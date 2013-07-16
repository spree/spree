---
title: Payment Methods
---

## Introduction

Payment methods represent the different payment options available to customers during the checkout process on an e-commerce store. Spree supports online payments utilizing payment gateways as well as offline payments via checks. 

## Payment Gateways

Let's begin by explaining the difference between a Payment Gateway and a Merchant Account. 

**Payment Gateway** - A payment gateway is a service that authorizes credit card payments, processes them securely, and deposits the funds into your bank account. A payment gateway performs the same function as a credit card swipe machine at a restaurant or retail store. It just performs this function for purchases made online instead of in person.  

**Merchant Account** - A merchant account is a type of bank account that allows you to accept credit card payments online. If you have a retail business and already accept credit card payments in person then more than likely you have a merchant account. When you start to sell products online, you'll just need to call your bank and ask that they set you up with an *Internet* merchant account. An internet merchant account allows you to accept payments online without having the customer's credit card physically in front of you. 

It's become popular in the last few years for payment gateway providers to offer an all-in-one solution that includes both the gateway and the merchant account. 


## Costs

Payment Gateways charge for their services in a variety of ways. Here are a few of the costs you might run into when evaluating providers:

**Setup Fee** - A one-time charge to set up your payment gateway account.

**Recurring Fixed Monthly Fees** - A fixed monthly fee that a payment gateway charges for access to their services and transaction reports. Some gateways break this charge down further into a monthly **Gateway Fee** and a **Statement Fee**. 

**Transaction Fees** - A charge by the payment gateway for each purchase made on your e-commerce store. The pricing structure for these fees may differ per gateway. A popular structure is to charge online retailers a percentage of the purchase cost plus a flate fee. For example, 2.9% plus $0.30 per transaction.  

## Add a Payment Method

Spree enables you to utilize the payment gateway of your choice. We have two [preferred partners](http://spreecommerce.com/products/payment_processing)(Bank Card Services in the United States and Braintree internationally), and a long list of payment gateways that are supported in Spree by default. But, overall we are agnostic to the payment gateway that you choose for your store. The gateways that are supported in Spree by default are listed [here](https://github.com/Shopify/active_merchant#supported-direct-payment-gateways).

To configure one of the supported payment gateways your developer must first install the [Spree_Gateway](https://github.com/spree/spree_gateway) extension on your store. Once this extension has been installed you can configure one of the supported gateways by going to the Admin Dashboard, clicking the **Configuration** tab, and clicking the **New Payment Method** button. In the **Provider** drop down menu you will see a long list of gateways (if you installed the [Spree_Gateway](https://github.com/spree/spree_gateway) extension). Select the one that you would like to add. 

![Select Payment Gateway Provider](/images/user/add_payment_provider.jpg)

# Environment

Choose which environment you would like to enable the payment method for. The choices are:

**Development** - Used by developers when they are testing a Spree store on their local machine.
**Production** -  Select if you want the payment gateway to appear on the customer facing version of your store
**Test** - Used by developers who are testing their Spree store utilizing our [test suite](/developer/testing.html). 

# Display

Select if you want the payment method to appear on the Frontend or the Backend of your store or both. The Front End is the customer facing version of your store. Selecting Front End means that the payment method will display as a payment option to your customers during the checkout step (Note: you must also select *Yes* for the **Active** option below for the gateway to appear). The Back End is the Admin Dashboard for your store. Users typically select this option when they want to make a payment option available to their staff but not to their end customers. For example, you might want to offer purchase orders as a payment option to customers on a one-off basis but only if they contact one of your customer service representatives via email or telephone. 

# Active

Select if you want the payment method to be active on your store or not. 

# Name

Give the payment method a name. The value you enter will appear on the customer facing version of your store on the Payment page during checkout as seen below.

![Payment Method Name](/images/user/payment_method_name.jpg)




$$$
Cover all of the steps involved in processing payments - including declined cards, chargebacks, refunds, etc.
$$$