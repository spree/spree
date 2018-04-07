---
title: REST API Customization
section: tutorial
---

## Introduction

In this tutorial we are going to learn how we can customize the **[REST API](../../api)** provided by Spree, adding a new endpoint (or you can override an existing in core). We will do this on the extension `spree_simple_sales` created in [Extensions tutorial](extensions_tutorial). If you don't see before,please, check them!

## Adding Custom Endpoints

Similarly to [Adding a Controller Action](extensions_tutorial.md#adding-a-controller-action-to-homecontroller) of [Extensions tutorial](extensions_tutorial), you can create a new controller class with a action that emits a json response from a [Rabl](https://github.com/nesquena/rabl) view.


### Creating the controller and action

Let's create a new custom endpoint to `api/v1/sales`. For this, make sure you are in the `spree_simple_sales` root directory and run the following command to create the directory structure for our new controller api:

```bash
$ mkdir -p app/controllers/spree/api/v1
```

Next, we will create the new controller `Spree::Api::V1:SalesController`, that inherit from `Spree::Api::BaseController` class.

So, create a new file in the directory we just created called `sales_controller.rb` and add the following content to it:


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

***
Note that distinct of `Spree::HomeController` from the previous tutorial, we are extending from `Spree::Api` module now
***

The difference from `Spree::HomeController.home` action is the 3 last extra lines, that perform:

- `expires_in`: Define the time that the endpoint expires
- `headers[]`: In addition to `expires_in`, returns a header to client with that time expiration
- `respond_with`: Normalize the response before parser to json. See [`ActionController::Base.respond_with`](../../../../core/lib/spree/core/controller_helpers/respond_with.rb)


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

***
The `only:` symbol defines which actions of the controller are allowed to be endpoints. Whether you don't define this, Spree will try execute a `SalesController.show()` action method, that in this case, not exists!
***

### Creating a View

Now, let's create a view to return the data defined in action for client. Spree uses [Rabl](https://github.com/nesquena/rabl) gem for field customizations, inheritance of specifications from the other `.rabl` files and many other cool features. This gem do something similar to [grape-entity](https://github.com/ruby-grape/grape-entity) presenters.

First, create the required views directory with the following command:

```bash
# The view needs be [controller]/[action].[api_version].rabl
$ mkdir -p app/views/spree/api/v1/sales/index.v1.rabl
```

Next, create the file `app/views/spree/api/v1/sales/index.v1.rabl` and add the following content to it:

```erb
collection @products
attributes *product_attributes
```

Open your terminal and execute the rails console:

```bash
rails console
```

Fetch the api key of any user of your database (e.g admin user):

```ruby
user = Spree::user_class.first
api_key = user.spree_api_key # Copy the api_key value
```

Now, when we head to `http://localhost:3000/api/v1/sales`, passing the header `X-Spree-Token: [YOUR_COPIED_API_KEY]` into your browser or any REST client, we should see the json result with all productis with sale price. 

***
Note that you will likely need to restart our example Spree application (created in the [Getting Started](getting_started_tutorial) tutorial).
***