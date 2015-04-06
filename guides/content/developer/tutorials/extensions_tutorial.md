---
title: Extensions
section: tutorial
---

## Introduction

This tutorial continues where we left off in the [Getting Started](getting_started_tutorial) tutorial. Now that we have a basic Spree store up and running, let's spend some time customizing it. The easiest way to do this is by using Spree extensions.

### What is a Spree Extension?

Extensions are the primary mechanism for customizing a Spree site. They provide a convenient mechanism for Spree developers to share reusable code with one another. Even if you do not plan on sharing your extensions with the community, they can still be a useful way to reuse code within your organization. Extensions are also a convenient mechanism for organizing and isolating discrete chunks of functionality.

### Finding Useful Spree Extensions in the Extension Registry

The [Spree Extension Registry](http://spreecommerce.com/extensions) is a searchable collection of Spree Extensions written and maintained by members of the [Spree Community](http://spreecommerce.com/community). If you need to extend your Spree application's functionality, be sure to have a look in the Extension Registry first; you may find an extension that either implements what you need or provides a good starting point for your own implementation. If you write an extension and it might be useful to others, [publish it in the registry](http://spreecommerce.com/extensions/new) and people will be able to find it and contribute as well.

## Installing an Extension

We are going to be adding the [spree_i18n](https://github.com/spree-contrib/spree_i18n) extension to our store. SpreeI18n is a extension containing community contributed translations of Spree & ability to supply different attribute values per language such as product names and descriptions. Extensions can also add models, controllers, and views to create new functionality.

There are three steps we need to take to install spree_i18n.

First, we need to add the gem to the bottom of our `Gemfile`:

```ruby
gem 'spree_i18n', git: 'git://github.com/spree/spree_i18n.git', branch: '3-0-stable'
```
****

Note that if you are using the edge version of Spree, you should omit the branch parameter to get the latest version of spree_i18n. Alternatively, you should select the version of spree_i18n that corresponds with your version of spree.

***
If you are using a 3.0.x version of Spree, the above line will work fine. If you're using a 2.4.x version of Spree, you'll need to change the "branch" option to point to the "2-4-stable" branch. If you're using the "master" branch of Spree, change the "branch" argument for "spree_i18n" to be "master" as well.
***

Now, let's install the gem via Bundler with the following command:

```bash
$ bundle install
```

Finally, let's copy over the required migrations and assets from the extension with the following command:

```bash
$ rails g spree_i18n:install
```

Answer **yes** when prompted to run migrations.

## Creating an Extension

Suppose we want the ability to mark certain products as being on sale. We'd like to be able to set a sale price on a product and show products that are on sale on a separate sale page. This is a great example of how an extension can be used to build on the solid Spree foundation.

Let's build a simple extension and install it into the Spree application we created in the [last tutorial](/developer/getting_started.html). This will allow us to see how the extension works with an actual Spree store while we develop it.

### Getting Started

Let's start by generating the extension. Run the following command from a directory of your choice outside of the `mystore` Spree application:

```bash
$ spree extension simple_sales
```

This creates a `spree_simple_sales` directory containing a skeleton structure for our new extension.

### Installing our Extension to the Spree Application

Now we'll install our extension. These steps are the same as [Installing an Extension](#installing-an-extension) above, except this time we're going to point the `:path` entry in the `Gemfile` to the directory containing the code for our new extension.

Firstly, change to the `mystore` application directory and add the following line to the bottom of the `Gemfile`. You may have to adjust the path somewhat depending on where you created the extension. You want this to be the path relative to the location of the `mystore` application.

```ruby
gem 'spree_simple_sales', :path => '../spree_simple_sales'
```

Once you have added the gem, it's time to bundle:

```bash
$ bundle install
```

Finally, let's run the `spree_simple_sales` install generator.

```bash
$ rails g spree_simple_sales:install
```

This adds the extension's assets to the appiication and optionally copies and runs its database migrations. Our new extension doesn't have any of these yet so let's add some customisations.

## Customising Extensions

Our mystore app now has the `spree_simple_sales` extension installed, although it doesn't actually do anything yet.

To create a new page that displays variants that are on sale, we're going to make changes to the same types of components to our extension as we would in any normal Rails application: models, controllers, views and routes.

### Adding a Sale Price to Variants

We need somewhere to store the sale price for [Variants](http://guides.spreecommerce.com/products_and_variants.html#what-is-a-variant). To do that we'll create a migration that adds a sale_price column to the spree_variants table. Change back to the `spree_simple_sales` directory and run:

```bash
$ rails g migration add_sale_price_to_spree_variants sale_price:decimal
```

Because we are dealing with prices, we need to now edit the generated migration to ensure the correct precision and scale. Edit the file `db/migrate/XXXXXXXXXXX_add_sale_price_to_spree_variants.rb` so that it contains the following:

```ruby
class AddSalePriceToSpreeVariants < ActiveRecord::Migration
  def change
    add_column :spree_variants, :sale_price, :decimal, :precision => 8, :scale => 2
  end
end
```


### Displaying Variants on Sale

Extensions can contain entirely new components, or they can use decorator classes to customise any of the provided Spree components. In this example, we'll learn how to use decorators.

#### Decorating the Product model

In order to select all of the Products with a sale price assigned, we'll add a scope to the Spree::Product model.

Create a directory to hold our decorator:

```bash
$ mkdir -p app/models/spree
```

Create a file in this directory called `product_decorator.rb` and add the following content to it:

```ruby
module Spree
  Product.class_eval do
    scope :on_sale, -> { joins(:variants_including_master).where('spree_variants.sale_price is not null').uniq }
  end
end
```

This scope selects just the products that have a variant with a `sale_price` set.

#### Adding a Route

Our new sale page is going to live at the url /sale, so we need to add a route. Update the `config/routes.rb` file to contain the following:

```ruby
Spree::Core::Engine.routes.draw do
  get "/sale" => "home#sale"
end
```

#### Extending the HomeController

The new route specifies a `sale` action in the `home` controller. To implement this, we're going to extend `Spree::HomeController` using a decorator.

The `Spree::HomeController` controller is provided by the spree_frontend gem so we need to make that a dependency of our extension. To do this add the following to the `spree_simple_sales.gemspec` file.

```ruby
s.add_dependency 'spree_frontend', '~> 3.0.0'
```

To create our decorator run the following command to create the directory:

```bash
$ mkdir -p app/controllers/spree
```

Next, create a new file in this directory called `home_controller_decorator.rb` and add the following content to it:

```ruby
module Spree
  HomeController.class_eval do
    def sale
      @products = Product.on_sale
    end
  end
end
```

This uses the new scope from our Product decorator to assign the products that have a variant with a `sale_price` set.

#### Creating a View

The sale action in the `HomeController` needs a template to display them. Let's create a view.

First, create the required views directory with the following command:

```bash
$ mkdir -p app/views/spree/home
```

Next, create the file `app/views/spree/home/sale.html.erb` and add the following content to it:

```erb
<div data-hook="homepage_products">
  <%%= render 'spree/shared/products', :products => @products %>
</div>
```

#### Running Migrations from an Extension

When we installed our extension, the install generator asked whether we wanted to run migrations but we hadn't added any at that point.

Now that we have a migration, we need to run it in the `mystore` application. To do this, change back to the `mystore` directory and run:

```bash
$ rake spree_simple_sales:install:migrations
Copied migration XXXXXXXXXXX_add_sale_price_to_spree_variants.spree_simple_sales.rb from spree_simple_sales
$ rake db:migrate
== XXXXXXXXXXX AddSalePriceToSpreeVariants: migrating ======================
-- add_column(:spree_variants, :sale_price, :decimal, {:precision=>8, :scale=>2})
   -> 0.0009s
== XXXXXXXXXXX AddSalePriceToSpreeVariants: migrated (0.0010s) =============
```

#### Setting the Sale Price for a Variant

Let's update the sample data so we have at least one product that is on sale in our application. We will need to do this in the rails console for the time being, as we have no admin interface to set sale prices for variants. We will be adding this functionality in the [Deface overrides tutorial](/developer/deface_overrides_tutorial.html).

Again in the `mystore` directory and open up the rails console:

```bash
$ rails console
```

Now, follow these steps to select a product and update its master variant to have a sale price. Note, you may not be editing the exact same product, but this is not important. We just need one "on sale" product to display on the sales page.

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

#### Running the Extension

Start the rails server and navigate to `http://localhost:3000/sale` you should now see the product(s) listed that we set a `sale_price` in the previous step.

However, if you look at the price, you'll notice that the price shown is incorrect: the Variant's original price is shown instead of the sale price. In order to fix this we'll start by writing unit tests to describe the behaviour we expect.

### Testing Extensions

It's always a good idea to test your code. We should be extra careful to write tests for our Variant decorator since we are modifying core Spree functionality. Let's write a couple of simple unit tests for `variant_decorator.rb`

#### Generating the Test App

An extension is not a full Rails application, so we need something to test our extension against. By running the Spree `test_app` rake task, we can generate a barebones Spree application within our `spec` directory to run our tests against.

We can do this with the following command from the root directory of our extension:

```bash
$ rake test_app
```

After this command completes, you should be able to run

```bash
$ rspec
```

and see the following output:

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
      variant = create(:variant, :sale_price => 8.00)
      expected = Spree::Price.new(:variant_id => variant.id, :currency => "USD", :amount => variant.sale_price)

      result = variant.price_in("USD")

      result.variant_id.should == expected.variant_id
      result.amount.to_f.should == expected.amount.to_f
      result.currency.should == expected.currency
    end

    it "returns the normal price if it is not on sale" do
      variant = create(:variant, :price => 15.00)
      expected = Spree::Price.new(:variant_id => variant.id, :currency => "USD", :amount => variant.price)

      result = variant.price_in("USD")

      result.variant_id.should == expected.variant_id
      result.amount.to_f.should == expected.amount.to_f
      result.currency.should == expected.currency
    end
  end
end
```

These specs test that the `price_in` method we overrode in our `VariantDecorator` returns the correct price both when the sale price is present and when it is not.

Running

```bash
$ rspec
```

again should give the following output:

```bash
F.

Failures:

  1) Spree::Variant#price_in returns the sale price if it is present
     Failure/Error: result.amount.to_f.should == expected.amount.to_f
       expected: 8.0
            got: 19.99 (using ==)
     # ./spec/models/spree/variant_decorator_spec.rb:12:in `block (3 levels) in <top (required)>'

Finished in 0.68754 seconds (files took 5.13 seconds to load)
2 examples, 1 failure

Failed examples:

rspec ./spec/models/spree/variant_decorator_spec.rb:5 # Spree::Variant#price_in returns the sale price if it is present
```

Let's fix our extension so that it uses the `sale_price` when it is present and passes the tests.

Next, create the file `app/models/spree/variant_decorator.rb` and add the following content to it:

```ruby
module Spree
  Variant.class_eval do
    alias_method :orig_price_in, :price_in
    def price_in(currency)
      return orig_price_in(currency) unless sale_price.present?
      Spree::Price.new(:variant_id => self.id, :amount => self.sale_price, :currency => currency)
    end
  end
end
```

Here we alias the original method `price_in` to `orig_price_in` and override it. If there is a `sale_price` present on the product's master variant, we return that price. Otherwise, we call the original implementation of `price_in`.

Now running

```bash
$ rspec
```

should show:

```bash
..

Finished in 0.56229 seconds (files took 3.29 seconds to load)
2 examples, 0 failures
```

Running the rails server again and navigating to the /sale page, we can see the sale price displayed.

## Versioning your extension

Different versions of Spree may act differently with your extension. It's advisable to keep different branches of your extension actively maintained for the different branches of Spree so that your extension will work with those different versions.

It's advisable that your extension follows the same versioning pattern as Spree itself. If your extension is compatible with Spree 3.0.x, then create a `3-0-stable` branch on your extension and advise people to use that branch for your extension. If it's only compatible with 243.x, then create a 2-4-stable branch and advise the use of that branch.

Having a consistent branching naming scheme across Spree and its extensions will reduce confusion in the long run.

## Summary

In this tutorial you learned how to both install extensions and create your own. A lot of core Spree development concepts were covered and you gained exposure to some of the Spree internals.

In the [next part](deface_overrides_tutorial) of this tutorial series, we will cover [Deface](https://github.com/spree/deface) overrides and look at ways to improve our current extension.
