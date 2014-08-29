---
title: Product Options
---

## Option Types and Option Values

Option Types are a way to help distinguish products in your store from one another. They are particularly useful when you have many products that are basically of the same general category (Tshirts or mugs, for example), but with characteristics that can vary, such as color, size, or logo.

For each Option Type, you will need to create one or more corresponding Option Values. If you create a "Size" Option Type, then you would need Option Values for it like "Small", "Medium", and "Large".

### Creating Option Types and Option Values

Option Types and Option Values are created at the store level, not the product level. This means that you only have to create each Option Type and Option Value once. Once an Option Type and Option Value is created it can be associated with any product in your store. To create an Option Type, click "Products", then "Option Types", then "New Option Type".

![New Option Type](/images/user/products/new_option_type.jpg)

You are required to fill in two fields: "Name" and "Presentation". You will see this same pattern several places in the Admin Interface. "Name" generally is the short term (usually one or two words) for the option you want to store. "Presentation" is the wordier, more descriptive term that gives your site's visitors a little more detail.

***
NOTE: Sometimes the term "Display" is used instead of "Presentation" to indicate what is shown to the user on the Product Variant's page.
***

For our first Option Type - Size - enter "Size" for the Name and "Size of the Tumbler" as the Presentation. Click "Update".

When the screen refreshes, you see that Spree has helpfully provided you with a blank row in which you can enter your first Option Value for the new Option Type.

![New Option Value](/images/user/products/new_option_value.jpg)

We're going to need two Option Values (Large and Small) for the Size Option Value, so go ahead and click the "Add Option Value" button. This gives you two blank rows to work with.

"Name" is easy - "Large" for the first, and "Small" for the second. Let's input "24-ounce cup" in the "Display" field for the Large Option Value and "16-ounce cup" for the Small Option Value.

![Completed Option Values](/images/user/products/large_small_option_values.jpg)

When you click "Update", Spree saves the two new Option Values, associates them with the Size Option Type, and takes you to the list of all Option Types.

### Associating Option Values with a Product

Our Spree application now knows that we have an Option Type with corresponding Option Values,but it doesn't know which of our products should have those Option Types. We have to explicitly tell it about those associations. We can do so either when we create a new Product (if the options have already been created), or when we edit an existing product.

At the bottom of the Product edit form is a text box labeled "Option Types". When you click in this box, a drop-down appears with all of the Option Types you have defined for your store. All you have to do is click one or more of them to associate them with your Product.

![Option Types Dropdown List](/images/user/products/option_types_dropdown.jpg)

Don't forget to click "Update" to save your changes.