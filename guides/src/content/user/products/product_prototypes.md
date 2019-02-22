---
title: Prototypes
---

## Introduction

A Prototype is like a Product blueprint, useful for helping you add a group of similar new products to your store more quickly. The general procedure is that you create a Prototype which is associated with certain [Option Types](/user/products/product_options.html) and [Properties](/user/products/product_properties.html); then you create products based on that Prototype, and only need to fill in the values for those Option Types and Properties.

Imagine that you've just received a new shipment of picture frames from your supplier. Your new stock encompasses a variety of brands, sizes, colors, and materials, but they are all basically the same type of product. This is a prime use case for prototypes.

***
This guide presumes you have already created the [Option Types](/user/products/product_options.html) and [Properties](/user/products/product_properties.html) you need for your new prototype. If you haven't, you should do that first before proceeding.
***

### Creating a Prototype

To create a prototype, go to the Admin Interface and click "Products", then "Prototypes". Click the "New Prototype" button.

![New Prototype Form](../../../images/user/products/new_prototype.jpg)

Input a value for the "Name" field (such as "Picture Frames"), and choose the properties and options you want to associate with this type of product.

![Filled-In Prototype Form](../../../images/user/products/picture_frame_prototype.jpg)

Click the "Create" button. You should now see your new prototype in the "Prototypes" list.

![Prototypes List](../../../images/user/products/prototypes.jpg)

# Using a Prototype to Create Products

To create a new product based on the new prototype, click "Products" from the Admin Interface, then click the "New Product" button. Select "Picture Frames" from the "Prototypes" drop-down menu.

![Product From Prototype](../../../images/user/products/product_from_prototype.jpg)

When you do so, the Spree system shows you values for both of the Option Types you entered, so that it can automatically create [Product Variants](/user/products/creating_products.html#understanding-variants) for you for each of them.

Let's create the Product and all Variants for the fictional "Hinkledink Picture Frame" product. Input the product's Name, SKU, a Master Price (remember, you can change this for each variant), and make sure to set the Available On date to today, so it will show up in your store. Check the boxes for the options this particular product has, and click "Create".

***
Clicking the box next to an Option Type title will automatically check all of its Option Values for you.
***

![Prototype Option Types](../../../images/user/products/prototype_product_with_options.jpg)

Proceed with [creating the product](/user/products/creating_products.html) as you would normally, adding any missing fields not supplied by the prototype.

Be sure to update each of the Variants with corresponding images, SKUs, and - if applicable - correct pricing.
