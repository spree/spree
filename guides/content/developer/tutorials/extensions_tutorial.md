---
title: Extensions
section: tutorial
---

## Introduction

This tutorial continues where we left off in the [Getting Started](getting_started_tutorial) tutorial. Now that we have a basic Spree store up and running, let's spend some time customizing it. The easiest way to do this is by using Spree extensions.

### What is a Spree Extension?

Extensions are the primary mechanism for customizing a Spree site. They provide a convenient mechanism for Spree developers to share reusable code with one another. Even if you do not plan on sharing your extensions with the community, they can still be a useful way to reuse code within your organization. Extensions are also a convenient mechanism for organizing and isolating discrete chunks of functionality.

## Installing an Extension

We are going to be adding the [spree_i18n](https://github.com/spree-contrib/spree_i18n) extension to our store. SpreeI18n is a extension containing community contributed translations of Spree & ability to supply different attribute values per language such as product names and descriptions. Extensions can also add models, controllers, and views to create new functionality.

There are three steps we need to take to install spree_i18n.

First, we need to add the gem to the bottom of our `Gemfile`:

```ruby
gem 'spree_i18n', github: 'spree-contrib/spree_i18n', branch: 'master'
```

***
If you are using a 3.0.x or 2.x version of Spree, you'll need to change the `branch` to `X-X-stable`
to match the version of Spree you're using. For example, use `3-0-stable` if you're using Spree `3.0.x`.
***

Now, let's install the gem via Bundler with the following command:

```bash
$ bundle install
```

Finally, let's copy over the required migrations and assets from the extension with the following command:

```bash
$ bundle exec rails g spree_i18n:install
```

Answer **yes** when prompted to run migrations.

## Creating an Extension

### Getting Started

Let's build a simple extension. Suppose we want the ability to mark certain products as being on sale. We'd like to be able to set a sale price on a product and show products that are on sale on a separate products page. This is a great example of how an extension can be used to build on the solid Spree foundation.

So let's start by generating the extension. Run the following command from a directory of your choice outside of our Spree application:

```bash
$ spree extension simple_sales
```

This creates a `spree_simple_sales` directory with several additional files and directories. After generating the extension make sure you change to its directory:

```bash
$ cd spree_simple_sales
```

### Adding a Sale Price to Variants

The first thing we need to do is create a migration that adds a sale_price column to [variants](/developer/products.html#variants).

We can do this with the following command:

```bash
bundle exec rails g migration add_sale_price_to_spree_variants sale_price:decimal
```

Because we are dealing with prices, we need to now edit the generated migration to ensure the correct precision and scale. Edit the file `db/migrate/XXXXXXXXXXX_add_sale_price_to_spree_variants.rb` so that it contains the following:

```ruby
class AddSalePriceToSpreeVariants < SpreeExtension::Migration[4.2]
  def change
    add_column :spree_variants, :sale_price, :decimal, precision: 8, scale: 2
  end
end
```

***
We're not inheriting directly from ActiveRecord::Migration, instead we're using
[SpreeExtension::Migration](https://github.com/spree-contrib/spree_extension/blob/master/lib/spree_extension/migration.rb) to support multiple Rails versions.
***

### Adding Our Extension to the Spree Application

Before we continue development of our extension, let's add it to the Spree application we created in the [last tutorial](/developer/getting_started_tutorial.html). This will allow us to see how the extension works with an actual Spree store while we develop it.

Within the `mystore` application directory, add the following line to the bottom of our `Gemfile`:

```ruby
gem 'spree_simple_sales', path: '../spree_simple_sales'
```

You may have to adjust the path somewhat depending on where you created the extension. You want this to be the path relative to the location of the `mystore` application.

Once you have added the gem, it's time to bundle:

```bash
$ bundle install
```

Finally, let's run the `spree_simple_sales` install generator to copy over the migration we just created (answer **yes** if prompted to run migrations):

```bash
# context: Your Spree store's app root (i.e. Rails.root); not the extension's root path.
$ rails g spree_simple_sales:install
```

### Adding a Controller Action to HomeController

Now we need to extend `Spree::HomeController` and add an action that selects "on sale" products.

***
Note for the sake of this example that `Spree::HomeController` is only included
in spree_frontend so you need to make it a dependency on your extensions *.gemspec file.
***

Make sure you are in the `spree_simple_sales` root directory and run the following command to create the directory structure for our controller decorator:

```bash
$ mkdir -p app/controllers/spree
```

Next, create a new file in the directory we just created called `home_controller_decorator.rb` and add the following content to it:

```ruby
Spree::HomeController.class_eval do
  def sale
    @products = Spree::Product.joins(:variants_including_master).where('spree_variants.sale_price is not null').distinct
  end
end
```

This will select just the products that have a variant with a `sale_price` set.

We also need to add a route to this action in our `config/routes.rb` file. Let's do this now. Update the routes file to contain the following:

```ruby
Spree::Core::Engine.routes.draw do
  get "/sale" => "home#sale"
end
```

### Viewing On Sale Products

#### Setting the Sale Price for a Variant

Now that our variants have the attribute `sale_price` available to them, let's update the sample data so we have at least one product that is on sale in our application. We will need to do this in the rails console for the time being, as we have no admin interface to set sale prices for variants. We will be adding this functionality in the [next tutorial](deface_overrides_tutorial) in this series, Deface overrides.

So, in order to do this, first open up the rails console:

```bash
$ rails console
```

Now, follow the steps I take in selecting a product and updating its master variant to have a sale price. Note, you may not be editing the exact same product as I am, but this is not important. We just need one "on sale" product to display on the sales page.

```irb
> product = Spree::Product.first
=> #<Spree::Product id: 107377505, name: "Spree Bag", description: "Lorem ipsum dolor sit amet, consectetuer adipiscing...", available_on: "2013-02-13 18:30:16", deleted_at: nil, permalink: "spree-bag", meta_description: nil, meta_keywords: nil, tax_category_id: 25484906, shipping_category_id: nil, count_on_hand: 10, created_at: "2013-02-13 18:30:16", updated_at: "2013-02-13 18:30:16", on_demand: false>

> variant = product.master
=> #<Spree::Variant id: 833839126, sku: "SPR-00012", weight: nil, height: nil, width: nil, depth: nil, deleted_at: nil, is_master: true, product_id: 107377505, count_on_hand: 10, cost_price: #<BigDecimal:7f8dda5eebf0,'0.21E2',9(36)>, position: nil, lock_version: 0, on_demand: false, cost_currency: nil, sale_price: nil>

> variant.sale_price = 8.00
=> 8.0

> variant.save
=> true
```

### Creating a View

Now we have at least one product in our database that is on sale. Let's create a view to display these products.

First, create the required views directory with the following command:

```bash
$ mkdir -p app/views/spree/home
```

Next, create the file `app/views/spree/home/sale.html.erb` and add the following content to it:

```erb
<div data-hook="homepage_products">
  <%%= render 'spree/shared/products', products: @products %>
</div>
```

If you navigate to `http://localhost:3000/sale` you should now see the product(s) listed that we set a `sale_price` on earlier in the tutorial. However, if you look at the price, you'll notice that it's not actually displaying the correct price. This is easy enough to fix and we will cover that in the next section.

### Decorating Variants

Let's fix our extension so that it uses the `sale_price` when it is present.

First, create the required directory structure for our new decorator:

```bash
$ mkdir -p app/models/spree
```

Next, create the file `app/models/spree/variant_decorator.rb` and add the following content to it:

```ruby
Spree::Variant.class_eval do
  alias_method :orig_price_in, :price_in
  def price_in(currency)
    return orig_price_in(currency) unless sale_price.present?
    Spree::Price.new(variant_id: self.id, amount: self.sale_price, currency: currency)
  end
end
```

Here we alias the original method `price_in` to `orig_price_in` and override it. If there is a `sale_price` present on the product's master variant, we return that price. Otherwise, we call the original implementation of `price_in`.

### Testing Our Decorator

It's always a good idea to test your code. We should be extra careful to write tests for our Variant decorator since we are modifying core Spree functionality. Let's write a couple of simple unit tests for `variant_decorator.rb`

#### Generating the Test App

An extension is not a full Rails application, so we need something to test our extension against. By running the Spree `test_app` rake task, we can generate a barebones Spree application within our `spec` directory to run our tests against.

We can do this with the following command from the root directory of our extension:

```bash
$ bundle exec rake test_app
```

After this command completes, you should be able to run `rspec` and see the following output:

```bash
No examples found.

Finished in 0.00005 seconds
0 examples, 0 failures
```

Great! We're ready to start adding some tests. Let's replicate the extension's directory structure in our spec directory by running the following command

```bash
$ mkdir -p spec/models/spree
```

Now, let's create a new file in this directory called `variant_decorator_spec.rb` and add the following tests to it:

```ruby
require 'spec_helper'

describe Spree::Variant do
  describe "#price_in" do
    it "returns the sale price if it is present" do
      variant = create(:variant, sale_price: 8.00)
      expected = Spree::Price.new(variant_id: variant.id, currency: "USD", amount: variant.sale_price)

      result = variant.price_in("USD")

      expect(result.variant_id).to eq(expected.variant_id)
      expect(result.amount.to_f).to eq(expected.amount.to_f)
      expect(result.currency).to eq(expected.currency)
    end

    it "returns the normal price if it is not on sale" do
      variant = create(:variant, price: 15.00)
      expected = Spree::Price.new(variant_id: variant.id, currency: "USD", amount: variant.price)

      result = variant.price_in("USD")

      expect(result.variant_id).to eq(expected.variant_id)
      expect(result.amount.to_f).to eq(expected.amount.to_f)
      expect(result.currency).to eq(expected.currency)
    end
  end
end
```

These specs test that the `price_in` method we overrode in our `VariantDecorator` returns the correct price both when the sale price is present and when it is not.

## Summary

In this tutorial you learned how to both install extensions and create your own. A lot of core Spree development concepts were covered and you gained exposure to some of the Spree internals.

In the [next part](deface_overrides_tutorial) of this tutorial series, we will cover [Deface](https://github.com/spree/deface) overrides and look at ways to improve our current extension.
