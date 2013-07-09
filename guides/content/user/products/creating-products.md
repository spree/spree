---
title: Creating a New Product
section: creating-products
---

## Introduction

To create a new product for your store, go into the Admin Dashboard, click the *Products* tab, and click the *New Product* button.

![New Product Entry Form](/images/user/new_product_entry_form.jpg)

The two mandatory fields (**Name** and **Master Price**) are denoted with an asterisk (&#42;) next to the label. You can leave SKU blank. If you don't add a value for **Available On** the product will not be shown in your store.

***
[Prototypes](prototypes.md) are a more complex topic, and are covered in their own guide.
***

## Product Details

After you click the *Create* button, the Spree application brings you to a more detailed product entry page, where you can input more information about your new product.

![Product Edit Form](/images/user/product_edit_form.jpg)

* **Name** - This field will either be blank, or the same as what you entered on the initial page. You can change this field whenever you like.
* **Permalink** - The permalink is automatically created by the application for you when the product is first saved, and is based on the product's name. This is what is appended to the end of a URL when someone visits the page for a particular product. You can change the permalink, but should exercise extreme caution in doing so to avoid naming collisions with other products in your database.
* **Description** - This is where you will provide a detailed description of the product and its features. The application gives you plenty of room to be thorough.
$$$
Add a topic on available markup options for this field - lists, links, etc.
$$$
* **Master Price** - For now, just think about the Master Price as the price you charge someone to buy the item. Later in this guide, you will learn more about variants and how they impact a product's actual price.
* **Cost Price** - What the item costs you, the seller, to purchase or produce.
* **Cost Currency** - It may be that the currency used when you purchased the product is not the same as that you use in your store. Spree makes these conversions for you - just enter the code for the currency used in acquiring your inventory.
* **Available On** - This field will either be blank, or the same as what you entered on the initial page. You can change this field whenever you like.
* **SKU** - This field will either be blank, or the same as what you entered on the initial page. You can change this field whenever you like.
* **On Hand** - Your current inventory of the product - those available for purchase.
* **On Demand** - Means the item can be produced at will to match demand, so is not restricted by the number on hand. This can be used in concert with **On Hand** or alone.
$$$
Make sure what I have for On Demand is accurate.
$$$
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

## Understanding Variants

Suppose that in your store, you sell drink tumblers. All are from the same manufacturer and have the same basic product specifications (materials used, machine washability rating, etc.), but your inventory includes several varieties:

* **Size** - You carry both Medium and Large tumblers
* **Decorative Wrap** - Your tumblers come with the option of several kinds of decorative plastic wraps on the outside. Customers can choose from Stars, Owls, Pink Paisley, Purple Paisley, or Skulls.
* **Lid Color** - Every quality tumbler needs a quality lid. Yours are available with an assortment of lids to match the decorative wrap - the Star tumblers have Blue lids, the Owls have Orange lids, the Pink Paisley have Pink lids, the Purple Paisley have White lids, and the Skulls can be purchased with White *or* Black lids.

Given this inventory, you need to have a Drink Tumbler *Product*, and twelve *Variants*:

Size  | Wrap           | Lid Color
------|----------------|----------
Large | Stars          | Blue
Small | Stars          | Blue
Large | Owls           | Orange
Small | Owls           | Orange
Large | Pink Paisley   | Pink
Small | Pink Paisley   | Pink
Large | Purple Paisley | White
Small | Purple Paisley | White
Large | Skulls         | White
Large | Skulls         | Black
Small | Skulls         | White
Small | Skulls         | Black

As you can see, we need to establish three different *Option Types* - Size, Wrap, and Lid Color - with appropriate Option Values for each.

Option Type | Option Values
------------|--------------
Size        | Large, Small
Wrap        | Stars, Owls, Pink Paisley, Purple Paisley, Skulls
Lid Color   | Blue, Orange, Pink, White, Black

### Creating Option Types and Option Values

You have to establish your Option Types and Option Values before you can set up your Variants. Click Products > Option Types > New Option Type.

![New Option Type](/images/user/new_option_type.jpg)

Let's add the first Option Type for our tumblers. You are required to fill in two fields: **Name** and **Presentation**. You will see this same pattern several places in the Spree Admin interface. **Name** generally is the short term (usually one or two words) for the option you want to store. **Presentation** is the wordier, more descriptive term that gives you site's visitors a little more detail.

***
NOTE: Sometimes the term "Display" is used instead of "Presentation" to indicate what is shown to the user on the Product Variant's page.
***

For our first Option Type - Size - enter "Size" for the Name and "Size of the Tumbler" as the Presentation. Click Update.

When the screen refreshes, you see that Spree has helpfully provided you with a blank row in which you can enter your first Option Value for the new Option Type.

![New Option Value](/images/user/new_option_value.jpg)

Since we know we're going to need two Option Values (Large and Small) for the Size Option Value, go ahead and click the Add Option Value button. This gives you two blank rows to work with.

**Name** is easy - "Large" for the first, and "Small" for the second. Let's input "24-ounce cup" in the **Display** field for the Large Option Value and "16-ounce cup" for the Small Option Value.

![Completed Option Values](/images/user/large_small_option_values.jpg)

When you click Update, Spree saves the two new Option Values, associates them with the Size Option Type, and takes you to the list of all Option Types.

Click the New Option Type button and similarly input the other two Option Types (along with their Option Values) we need for our tumblers.

### Associating Option Values with a Product

Our Spree application now knows that we have three different Option Types, each with its own set of Option Values, but it doesn't know which of our products should have those Option Types. We have to explicitly tell it about those associations. We can do so either when we create a new Product (if the options already exist) or when we edit an existing one.

At the bottom of the Product edit form is a text box labeled **Option Types**. When you click in this box, a drop-down appears with all of the Option Types you have defined for your store. All you have to do is click one or more of them to associate them with your Product. We, of course, want to associate all three Option Values with our tumbler Product.

![Option Types Dropdown List](/images/user/option_types_dropdown.jpg)

Don't forget to click **Update** to save your changes.

### Creating Variants

Now that you have set up the appropriate options for your Product's Variants and associated those options with the product, you can create the Variants themselves.

Let's create the large, star-wrapped, blue-lidded tumbler Variant as an example. You can then use the same approach to creating all of the other Variants we mentioned earlier.

On your tumbler product edit page, click the **Variants** link. Click the **New Variant** button. Select the appropriate values for the Option Types.

As you can see, you also have the option to enter values for this particular Variant that may be different from what you input on the Product's main page. Let's raise the price on our Variant to $20, and indicate that we have 2 On Hand. Click the **Create** button.

![New Product Variant](/images/user/new_variant.jpg)

## Product Properties

Depending on the nature of your store and the products you sell, you may want to add additional properties to your store's products. Let's suppose, for example, that you specialize in products from the [Fair World Project](http://fairworldproject.org/). You may want to add a property to all of the products to record the country of origin. The Spree application makes this very easy to do:

1. Click the **Products** tab in your Admin Dashboard.
2. Click **Properties**.
3. Click the **New Property** button.
4. Enter values for the **Name** and **Presentation** fields, such as "Origin" and "Country of Origin", respectively.
5. Click the **Create** button.
6. Navigate to the edit page for one of the products in your store.
7. Click the **Product Properties** link.
8. Click in the empty text box field under **Property** and start typing the name of the property you want to use: "Origin". After you type a few letters, the property name will display, and you can click it to select it.
9. Enter a country name for the **Value** field, such as "Honduras".
10. Click **Update**.

Now, when you navigate to the product's page in your store, you will see the new Origin property in the "Properties" list.

![Properties List](/images/user/properties_list.jpg)

***
You can add as many **Product Properties** to an individual **Product** as you like - just use the **Add Product Properties** button on the Product Properties page for an individual product.
***

You can also add **Product Properties** on the fly as you're editing a **Product** - you don't have to specify them ahead of time. Just be cautious of defining too many similar properties ("Origin", "Country Origin", "Country of Origin"). It's best to re-use existing properties wherever you can.