---
title: Payment Methods
---

## Introduction

Payment methods represent the different payment options available to customers during the checkout process on an e-commerce store. Spree supports two general types of payment methods:

* Payment Gateways (credit cards, debit cards and PayPal)
* Checks


## Payment Gateways

It's helpful to understand the difference between a Payment Gateway and a Merchant Account. 

**Payment Gateway** - A payment gateway is a service that authorizes credit card payments, processes them securely, and deposits the funds into your bank account. A payment gateway performs the same function as a credit card swipe machine at a restaurant or retail store. It just performs this function for purchases made online instead of in person.  

**Merchant Account** - A merchant account is a type of bank account that allows you to accept credit card payments online. If you have a retail business and already accept credit card payments in person then more than likely you have a merchant account. When you start to sell products online, you'll just need to call your bank and ask that they set you up with an *Internet* merchant account. An internet merchant account allows you to accept payments online without having the customer's credit card physically in front of you. 

It's become popular in the last few years for payment gateway providers to offer an all-in-one solution that includes both the gateway and the merchant account. 


## Costs

Payment Gateways charge for their services in a variety of ways. Here are a few of the costs you might run into when evaluating providers:

**Setup Fee** - A one-time charge to set up your payment gateway account.

**Recurring Fixed Monthly Fees** - A fixed monthly fee that a payment gateway charges for access to their services and transaction reports. Some gateways break this charge down further into a monthly **Gateway Fee** and a **Statement Fee**. 

**Transaction Fees** - A charge by the payment gateway for each purchase made on your e-commerce store. The pricing structure for these fees may differ per gateway. A popular structure is to charge online retailers a percentage of the purchase cost plus a flate fee. For example, 2.9% plus $0.30 per transaction.  

## Adding Payment Methods

Spree enables you to utilize the payment gateway of your choice. We have a few preferred partners (Bank Card Services in the United States and Braintree internationally), and several payment gateways that are configured in Spree by default, but overall we are agnostic to the payment gateway that you choose to use for your store. 

Default Gateways
