---
title: "Products"
section: core
---

## Overview

`Product` records track unique products within your store. These differ from [Variants](#variants), which track the unique variations of a product. For instance, a product that's a T-shirt would have variants denoting its different colors. Together, Products and Variants describe what is for sale.

Products have the following attributes:

* `name`: short name for the product
* `description`: The most elegant, poetic turn of phrase for describing your product's benefits and features to your site visitors
* `permalink`: An SEO slug based on the product name that is placed into the URL for the product
* `available_on`: The first date the product becomes available for sale online in your shop. If you don't set the `available_on` attribute, the product will not appear among your store's products for sale.
* `deleted_at`: The date the product is no longer available for sale in the store
* `meta_description`: A description targeted at search engines for search engine optimization (SEO)
* `meta_keywords`: Several words and short phrases separated by commas, also targeted at search engines

To understand how variants come to be, you must first understand option types and option values.

## Option Types and Option Values

Option types denote the different options for a variant. A typical option type would be a size, with that option type's values being something such as "Small", "Medium" and "Large". Another typical option type could be a color, such as "Red", "Green", or "Blue".

A product can be assigned many option types, but must be assigned at least one if you wish to create variants for that product.

## Variants

`Variant` records track the individual variants of a `Product`. Variants are of two types: master variants and normal variants.

Variant records can track some individual properties regarding a variant, such as height, width, depth, and cost price. These properties are unique to each variant, and so are different from [Product Properties](#product-properties), which apply to all variants of that product.

### Master Variants

Every single product has a master variant, which tracks basic information such as a count on hand, a price and a SKU. Whenever a product is created, a master variant for that product will be created too.

Master variants are automatically created along with a product and exist for the sole purpose of having a consistent API when associating variants and [line items](orders#line-items). If there were no master variant, then line items would need to track a polymorphic association which would either be a product or a variant.

By having a master variant, the code within Spree to track  is simplified.

### Normal Variants

Variants which are not the master variant are unique based on [option type and option value](#option_type) combinations. For instance, you may be selling a product which is a Baseball Jersey, which comes in the sizes "Small", "Medium" and "Large", as well as in the colors of "Red", "Green" and "Blue". For this combination of sizes and colors, you would be able to create 9 unique variants:

* Small, Red
* Small, Green
* Small, Blue
* Medium, Red
* Medium, Green
* Medium, Blue
* Large, Red
* Large, Green
* Large, Blue

## Images

Images link to a product through its master variant. The sub-variants for the product may also have their own unique images to differentiate them in the frontend.

Spree automatically handles creation and storage of several size versions of each image (via the Paperclip plugin). The default styles are as follows:

```ruby
styles: {
  mini: '48x48>',
  small: '100x100>',
  product: '240x240>',
  large: '600x600>'
}
```

These sizes can be changed by altering the value of `Spree::Image.attachment_definitions[:attachment][:styles]`. Once `Spree::Image.attachment_definitions[:attachment][:styles]` has been changed, you *must* regenerate the paperclip thumbnails by running this command:

```bash
$ bundle exec rake paperclip:refresh:thumbnails CLASS=Spree::Image
```

If you want to change the image that is displayed when a product has no image, simply set `Spree::Image.attachment_definitions[:attachment][:default_url]` with a path to the image that you want to use like this: `/assets/images/missing_:style.png`. These image styles must match the keys within `Spree::Config[:attachment_styles]`. That means that ideally, you'd have four images of different sizes: `missing_mini.png`, `missing_small.png`, `missing_product.png`, and `missing_large.png`.

## Product Properties

Product properties track individual attributes for a product which don't apply to all products. These are typically additional information about the item. For instance, a T-Shirt may have properties representing information about the kind of material used, as well as the type of fit the shirt is.

A `Property` should not be confused with an [`OptionType`](#option_type), which is used when defining [Variants](#variants) for a product.

You can retrieve the value for a property on a `Product` object by calling the `property` method on it and passing through that property's name:

```bash
$ product.property("material")
=> "100% Cotton"
```

You can set a property on a product by calling the `set_property` method:

```ruby
product.set_property("material", "100% cotton")
```

If this property doesn't already exist, a new `Property` instance with this name will be created.

## Multi-Currency Support

`Price` objects track a price for a particular currency and variant combination. For instance, a [Variant](#variants) may be available for $15 (15 USD) and €7 (7 Euro).

This presence or lack of a price for a variant in a particular currency will determine if that variant is visible in the frontend. If no variants of a product have a particular price value for the site's current currency, that product will not be visible in the frontend.

You may see what price a product would be in the current currency (`Spree::Config[:currency]`) by calling the `price` method on that instance:

```bash
$ product.price
=> "15.99"
```

To find a list of currencies that this product is available in, call `prices` to get a list of related `Price` objects:

```bash
$ product.prices
=> [#<Spree::Price id: 2 ...]
```

## Prototypes

A prototype is a useful way to share common `OptionType` and `Property` combinations amongst many different products. For instance, if you're creating a lot of shirt products, you may wish to maintain the "Size" and "Color" option types, as well as a "Fitting Type" property.

## Taxons and Taxonomies

Taxonomies provide a simple, yet robust way of categorizing products by enabling store administrators to define as many separate structures as needed.

When working with Taxonomies there are two key terms to understand:

* `Taxonomy` – a hierarchical list which is made up of individual Taxons. Each taxonomy relates to one `Taxon`, which is its root node.
* `Taxon` – a single child node which exists at a given point within a `Taxonomy`. Each `Taxon` can contain many (or no) sub / child taxons. Store administrators can define as many Taxonomies as required, and link a product to multiple Taxons from each Taxonomy.

By default, both Taxons and Taxonomies are ordered by their `position` attribute.

Taxons use the [Nested set model](http://en.wikipedia.org/wiki/Nested_set_model) for their hierarchy. The `lft` and `rgt` columns in the `spree_taxons` table represent the locations within the hierarchy of the item. This logic is handled by the [awesome_nested_set](https://github.com/collectiveidea/awesome_nested_set) gem.

Taxons link to products through an intermediary model called `Classification`. This model exists so that when a product is deleted, all of the links from that product to its taxons are deleted automatically. A similar action takes place when a taxon is deleted; all of the links to products are deleted automatically.

Linking to a taxon in a controller or a template should be done using the `spree.nested_taxons_path` helper, which will use the taxon's permalink to
generate a URL such as `/t/categories/brand`.
