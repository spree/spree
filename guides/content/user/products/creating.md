---
title: Creating a New Product
---

[TODO] Fill in this user guide on all of the elements of a product and its variants.

# Creating Products

To create a new product for your store, go into the Admin Dashboard, click the *Products* tab, and click the *New Product* button.

![New Product Entry Form](/images/user/products/new_product_entry_form.jpg)

The two mandatory fields (**Name** and **Master Price**) are denoted with an asterisk (&#42;) next to the label. You can leave SKU blank. If you don't add a value for **Available On** the product will not be shown in your store.

***
[Prototypes](prototypes.md) are a more complex topic, and are covered in their own guide.
***

## Product Details

After you click the *Create* button, the Spree application brings you to a more detailed product entry page, where you can input more information about your new product.

![Product Edit Form](/images/user/products/product_edit_form.jpg)

* **Name** - This field will either be blank, or the same as what you entered on the initial page. You can change this field whenever you like.
* **Permalink** - The permalink is automatically created by the application for you when the product is first saved, and is based on the product's name. This is what is appended to the end of a URL when someone visits the page for a particular product. You can change the permalink, but should exercise extreme caution in doing so to avoid naming collisions with other products in your database.
* **Description** - This is where you will provide a detailed description of the product and its features. The application gives you plenty of room to be thorough. **TODO** Add a topic on available markup options for this field - lists, links, etc.
* **Master Price** - For now, just think about the Master Price as the price you charge someone to buy the item. Later in this guide, you will learn more about variants and how they impact a product's actual price.
* **Cost Price** - What the item costs you, the seller, to purchase or produce.
* **Cost Currency** - It may be that the currency used when you purchased the product is not the same as that you use in your store. Spree makes these conversions for you - just enter the code for the currency used in acquiring your inventory.
* **Available On** - This field will either be blank, or the same as what you entered on the initial page. You can change this field whenever you like.
* **SKU** - This field will either be blank, or the same as what you entered on the initial page. You can change this field whenever you like.
* **On Hand** - Your current inventory of the product - those available for purchase.
* **On Demand** - Means the item can be produced at will to match demand, so is not restricted by the number on hand. This can be used in concert with **On Hand** or alone.
**TODO** Make sure what I have for On Demand is accurate.
* **Weight** - The product's weight in ounces. May be used to calculate shipping cost.
* **Height** - The product's height in inches. May be used to calculate shipping cost.
* **Width** - The product's width in inches. May be used to calculate shipping cost.
* **Depth** - The product's depth or breadth in inches. May be used to calculate shipping cost.
* **Shipping Categories** - You will learn about setting up Shipping Categories in the [Shipping Guide](../config/shipping.md).
* **Tax Category** - You will learn about setting up Tax Categories in the [Taxes Guide](../config/taxes.md).
* **Taxons** - Taxons are basically like categories. You will learn more about them in the [Taxonomies Guide](../config/taxonomies.md).
* **Option Types** - You can select any number of Options to associate your new product with. You'll learn more about Options in the [Options Guide](options.md).
* **Meta Keywords** - These words are appended to the website's keywords you established in the [Site Settings](../config/general_settings.md) and can help improve your site's search engine ratings, bringing you more web traffic. They should be words that are key to your new product.
* **Meta Description** - The summary that someone sees when your product's page is returned in a web search. It should be descriptive but not overly verbose.

## Images

A store whose products had no images to look at would be pretty boring, and probably not garner a lot of sales. It would be very time-consuming to have to upload, crop, resize, and associate several photos to each product, if you had to do so manually. Luckily, Spree makes maintaining images of your products quick and painless. 

Just click the **Images** link under **Product Details** on the right-hand side of the screen. Any images that you may have already uploaded will be previewed for you. To add a new image for your product, click the **New Image** button. 

Select the Image file, and enter the Alternative Text for the image. Alternative Text is what appears when someone has their browser's image-rendering turned off, as with certain types of screen readers.

You have the option to associate a photo only with a particular **Variant** (again, more on Variants later in this guide), or with all of the product's Variants.

When you click Update, not only is the product photo uploaded, it is automatically resized and cropped to fit your store's requirements, and it is associated with the correct versions of your product.

## Variants

A product can have many variants...

To set up variants you must first Option Types and Option Values set up...

## Product Properties

Product Properties include…

The differences between properties, options, and variants are...