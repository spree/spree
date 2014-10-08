---
title: Returns
---

## Introduction

Returns are a reality of doing business for most e-commerce sites. A customer may find that the item they ordered doesn't fit, or that it doesn't fit their needs. The product may be damaged in shipping. There are many reasons why a customer could choose to return an item they purchased in your store. This guide covers how you, as the site administrator, issue RMAs (Return Merchandise Authorizations) and process returns.

## Creating RMAs for Returns

You can only create RMAs for orders that have already been shipped. That makes sense, as you wouldn't authorize a return for something you haven't sent out yet.

![Return Authorizations Link](/images/user/orders/return_authorizations_link.png)

To create an RMA for a shipped order, click the order's "Return Authorizations" link, then click the "New Return Authorization" button. The form that opens up enables you to select which items will be authorized to be returned, and issue an RMA for the corresponding amount.

![RMA Form](/images/user/orders/rma_form.png)

To use it, just select each line item to be returned, and either a reimbursement type or exchange item. Selecting the "Original" reimbursement type will refund a user back to their original payment method when the items are returned and approved.  Selecting an exchange item will create a new shipment to ship the exchange item to the customer.  The form will automatically calculate the RMA value based on the sale price of the item(s), but you will have to confirm the amount when the reimbursement is issued. This gives you a chance to adjust for handling fees, restocking fees, damages, etc.

Input the reason and any memo notes for the return, and select the [Stock Location](stock_locations) the item is coming back to. Click the "Create" button.

Now you just need to wait for the package to be received at your location.

## Processing Returns

Once you receive a return package, you need to create a "Customer Return". To do so, go to the order in question and click "Customer Returns". Click the "New Customer Return" button.

![Receive RMA Button](/images/user/orders/customer_return_link.png)

Select which of the authorized return items were received, and to which [Stock Location](stock_locations).  Once done click the "Create" button.

![Receive RMA Button](/images/user/orders/customer_return_form.png)

The return items are marked as accepted, and now you can create a reimbursement for the $22.99 you owe the customer.

![RMA Received](/images/user/orders/create_reimbursement_button.png)

The reimbursement form will be populated according to your original reimbursement or exchange selections chosen during the return authorization form.  You may override the selected reimbursement type or exchange item now if you would like, otherwise click the "Reimburse" button to create the refund.

![Issue a Reimbursement](/images/user/orders/reimbursement_form.png)

Your return-processing is complete!  As you can see there will now be a $22.99 refund issued to the original credit card.

![Reimbursement Complete](/images/user/orders/reimbursement_complete.png)
