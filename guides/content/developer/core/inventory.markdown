---
title: "Inventory"
---

## Overview

Spree uses a hybrid approach for tracking inventory: On-hand inventory
is stored as a count on the product *Variant*. This gives good
performance for stores with large inventories. Back-ordered, sold or
shipped products are stored as individual *InventoryUnit* objects so
they can have relevant information attached to them, e.g. tracking
information.

What if you don’t need to track inventory? We have come up with a design
that basically shields users of simple stores from much of this
complexity. Simply leave the inventory fields blank and you never have
to worry about it.

New products created in the system can be given a starting “on hand”
inventory level. You can subsequently set new inventory levels and the
correct things will happen, e.g. adding new on-hand inventory to an
out-of-stock product that has some backorders will first fill the
backorders then update the product with the remaining inventory count.

We’ve also done a great deal of improvement with variants. Every line
item in an order tracks the exact variant of the product sold. Things
work fine even if the product has no meaningful variant information (say
you are just selling CD’s and you don’t need to worry about “size”,
“color”, etc.) A “master” variant is created behind the scenes and your
inventory and SKU information will be associated with this variant. If
you do end up using variants though, you now have fine grained control
over the SKU and inventory information.

### Design and functionality

On-hand inventory is stored as attribute *count\_on\_hand* in the
Variant model. The on-hand inventory level is adjusted using
*Variant\#on\_hand= - enables/disables inventory management. When
disabled, Spree will not use/change stock levels and will not create
backorders - so effectively behaves as if there was infinite stock for
everything.
\
\**:show\_zero\_stock\_products+ (default: *true*) - when this is set to
*false*, Spree will only show products when at least one of its variants
has stock (or if stock checking has been disabled, as above). The
default is to show all products.

-   *:allow\_backorders* (default: *true*) - when this is *false*, Spree
    will only allow items to be added to orders when there is stock.
    This occurs both in the views (the controls for adding out of stock
    variants are disabled) and in the underlying models (a variant is
    only added to an order when there is sufficient stock). When it is
    true, stock deficiencies are converted to backordered
    *InventoryUnit* objects and the user is informed of the shortfall.

One other flag is relevant:

-   *:allow\_backorder\_shipping* (default: *false*) - allows inventory
    in the backorder state to be marked as shipped. You may need to do
    this in certain cases, e.g. if your backorders are handled by a 3rd
    party fulfillment house and they have agreed to ship an item once
    stock is available again.

#### What the customer sees

Generally, the settings above are the most significant. Customizations
can also access details of stock levels for each variant via the
*on\_hand* method, e.g. to show the current level on the cart page.

NOTE: stock levels will of course change over time, and there is **no
locking** of requested inventory to orders until the very last stage of
checkout. If stock checking is enabled and insufficient stock is
available at checkout, the shortfall is reported to the user (there is
no compulsory back-ordering).

#### What the orders administrator sees

As mentioned above, the admin interface hides some of the complexity of
the full system. \
When adding or editing the variants of a product, the merchant can set
or alter the stock \
level for each variant by changing a single number. If the product has
no variants (apart \
from the master variant), then the product’s stock level can be set on
the product \
details page.

Every sold (or backordered) item is represented by its own
*InventoryUnit* object, and \
these can be assigned to multiple shipments and/or returned by the
customer.

NOTE: the admin interface currently doesn’t explicitly highlight when a
shipment contains back-orders. However, if you try to mark such a
shipment as being shipped, an error message will appear - unless you
have *allow\_backorder\_shipping* set, that is.

##### Return authorizations

This is a new feature. After an order is shipped, administrators can
approve the \
return of some part (maybe all) of an order via the *Return
Authorizations* tab\
in the single order console. To create a new return authorization, you
should \
indicate which part of the order is being returned, what the reason for
return\
is, and what the resulting credit should be. The sale price of the
products is \
shown for reference, but you can choose any value you like.

After the authorization is created, you can return later to its edit
page and \
click on the ‘received’ button to register the return of goods. This
will \
create a credit adjustment on the order, which you can apply (i.e.
refund) \
to the order’s credit card via the payments screen. Spree will log the
events\
in the order’s history.

### Programming interface

Here’s a summary of methods you might use in an extension or replacement
theme \
(*v* is a variant, *p* is a product):

-   *v.on\_hand* - returns how many inventory items a variant has with
    the “on\_hand” state

-   *v.on\_hand=* - sets the inventory level, filling back-orders first
    if there are any

-   *v.in\_stock?* - returns true if at least one item is “on\_hand”

-   *p.has\_stock?* - returns true if any variant of the product is
    “on\_hand”

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
