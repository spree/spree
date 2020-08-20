---
title: API v1 Customization
section: customization
order: 7
---

<alert kind="warning">
  For API v2 customization please refer [API v2 section](/developer/customization/api_v2.html)
</alert>

## Introduction

In this tutorial we are going to learn how we can customize the **[REST API](../../api)** provided by Spree, adding a new endpoint (or you can override an existing in core). We will use `spree_simple_sales` extension created in [Extensions tutorial](/developer/tutorials/extensions_tutorial.html). If you haven't seen before, please check them!

## Adding Custom Endpoints

Similarly to adding a controller action of [Extensions tutorial](/developer/tutorials/extensions_tutorial.html), you can create a new controller class with an action that   emits a json response from a [Rabl](https://github.com/nesquena/rabl) view.


### Creating the controller and action

Let's create a new custom endpoint to `api/v1/sales`. For this, make sure you are in the `spree_simple_sales` root directory and run the following command to create the directory structure for our new controller api:

```bash
mkdir -p app/controllers/spree/api/v1
```

Next, we will create the new controller `Spree::Api::V1:SalesController`, that inherit from `Spree::Api::BaseController` class.

In the directory we just created add a new file called `sales_controller.rb` with the the following content:


```ruby
module Spree
  module Api
    module V1
      class SalesController < Spree::Api::BaseController
        def index
          @products = Spree::Product.joins(:variants_including_master).where('spree_variants.sale_price is not null').distinct

          expires_in 15.minutes, public: true

          headers['Surrogate-Control'] = "max-age=#{15.minutes}"
          respond_with(@products)
        end
      end
    end
  end
end
```

<alert kind="note">
  Note that distinct of `Spree::HomeController` from the previous tutorial, we are extending from `Spree::Api` module now
</alert>

The difference from `Spree::HomeController.home` action is the 3 last extra lines, that perform:

- `expires_in`: Define the time that the endpoint expires
- `headers[]`: In addition to `expires_in`, returns a header to client with that time expiration
- `respond_with`: Normalize the response before parser to json.

We also need to add a route to this endpoint/action in our `config/routes.rb` file. Let's do this now. Update the routes file to contain the following:

```ruby
Spree::Core::Engine.add_routes do
  # The route added in previous tutorial
  get "/sale" => "home#sale"

  namespace :api, defaults: { format: 'json' } do
    namespace :v1 do
      # Our new route goes here!
      resources :sales, only: [:index]
    end
  end
end
```

<alert kind="note">
  The `only:` symbol defines which actions of the controller are allowed to be endpoints. Whether you don't define this, Spree will try execute a `SalesController.show()` action method, that in this case, not exists!
</alert>

### Creating a View

Now, let's create a view to return the data defined in action for client. Spree uses [Rabl](https://github.com/nesquena/rabl) gem for field customizations, inheritance of specifications from the other `.rabl` files and many other cool features. This gem do something similar to [grape-entity](https://github.com/ruby-grape/grape-entity) presenters.

First, create the required views api directory with the following command:

```bash
# The view needs be [controller]/[action].[api_version].rabl
mkdir -p app/views/spree/api/v1/sales
```

Next, create the file `app/views/spree/api/v1/sales/index.v1.rabl` and add the following content to it:

```ruby
collection @products
attributes *product_attributes << :sale_price
```

### Testing Our endpoint

Like described in [Testing Our Decorator](/developer/tutorials/extensions_tutorial.html#testing-our-decorator) it's always a good idea to test your code, including your api new/changed endpoints. Let's write a integration test that simulate your api of simple unit tests for `sales_controller.rb`

#### Creating and running the test

1. Verify if the `Gemfile` of our extensions contains the gems below, into `:test` the group:

```ruby
group :test do
  gem 'rails-controller-testing'
  gem 'rspec-rails', '~> 3.8.0'
  gem 'rspec-activemodel-mocks'
end
```
> **PS:** The `rspec-activemodel-mocks` is need to use `stub_*` methods (e.g `stub_model` called by `stub_authentication!`)

2. `bundle install`

3. Copy the file [spree/controller_hacks.rb](https://github.com/spree/spree/blob/master/api/spec/support/controller_hacks.rb) to `spec/support` folder. That is required to use `api_*` methods to simulate api requests (e.g `api_get :action`, `api_post :action`...)

4. Replicate the extension's controller directory structure in our spec directory by running the following command

```bash
mkdir -p spec/controllers/spree/api/v1
```

Now, let's create a new file in this directory called `sales_controller_spec.rb` and add the following test to it:

```ruby
require 'spec_helper'

module Spree
  describe Api::V1::SalesController, type: :controller do
    render_views

    # 8.00 it's a example value. Use any other value that your wish!
    let!(:product) { create(:product, sale_price: 8.00) }
    let!(:other_product) { create(:product) }
    let!(:user) { create(:user) }

    before do
      # Mock API autentication using a "spree_api_key"
      stub_authentication!
    end

    it 'retrieves a list of products in sale' do
      api_get :index
      expect(json_response.size).to eq(1)
      expect(json_response.first["sale_price"].to_f).to eq(product.sale_price)
    end
  end
end
```

Open your terminal and execute `rspec` command to run all tests:

```bash
rspec
```

You should see the output below in your terminal:

```bash
3 examples found.

Finished in 0.00005 seconds
3 examples, 0 failures
```

#### Get the endpoint result

In your terminal, execute the `rails console`:

```bash
rails console
```

Fetch the api key of any user of your database (e.g admin user):

```ruby
user = Spree::user_class.first
api_key = user.spree_api_key # Copy the api_key value
```

Now, when we head to `http://localhost:3000/api/v1/sales`, passing the header `X-Spree-Token: [YOUR_COPIED_API_KEY]`, (or add a `?token=[YOUR_COPIED_API_KEY]`  to the url) into your browser or any REST client, we should see the json result with all products with a sale price.

<alert kind="note">
  Note that you will likely need to restart our example Spree application (created in the [Getting Started](/developer/tutorials/getting_started_tutorial.html) tutorial).
</alert>
