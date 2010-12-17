Rails.application.routes.draw do

  root :to => 'products#index'

  resources :products

  match '/locale/set' => 'locale#set'

  resources :tax_categories

  resources :countries, :only => :index do
    resources :states
  end

  resources :states, :only => :index

  # non-restful checkout stuff
  match '/checkout/update/:state' => 'checkout#update', :as => :update_checkout
  match '/checkout/:state' => 'checkout#edit', :as => :checkout_state
  match '/checkout' => 'checkout#edit', :state => 'address', :as => :checkout

  # non-restful admin checkout stuff
  match '/admin/orders/:order_number/checkout' => 'admin/checkout#update', :method => :post, :as => :admin_orders_checkout
  match '/admin/orders/:order_number/checkout/(:state)' => 'admin/checkout#edit', :method => :get, :as => :admin_orders_checkout

  resources :orders do
    post :populate, :on => :collection

    resources :line_items
    resources :creditcards
    resources :creditcard_payments

    resources :shipments do
      member do
        get :shipping_method
      end
    end

  end
  match '/cart', :to => 'orders#edit', :via => :get, :as => :cart
  match '/cart', :to => 'orders#update', :via => :put, :as => :update_cart
  match '/cart/empty', :to => 'orders#empty', :via => :put, :as => :empty_cart

  resources :shipments do
    member do
      get :shipping_method
      put :shipping_method
    end
  end

  #   # Search routes
  match 's/:product_group_query' => 'products#index', :as => :simple_search
  match '/pg/:product_group_name' => 'products#index', :as => :pg_search
  match '/t/*id/s/*product_group_query' => 'taxons#show', :as => :taxons_search
  match 't/*id/pg/:product_group_name' => 'taxons#show', :as => :taxons_pg_search

  #   # route globbing for pretty nested taxon and product paths
  match '/t/*id' => 'taxons#show', :as => :nested_taxons
  #
  #   #moved old taxons route to after nested_taxons so nested_taxons will be default route
  #   #this route maybe removed in the near future (no longer used by core)
  #   map.resources :taxons
  #



  namespace :admin do
    resources :zones
    resources :users
    resources :countries do
      resources :states
    end
    resources :states
    resources :tax_categories
    resources :configurations
    resources :products do
      resources :product_properties
      resources :images
      member do
        get :clone
      end
      resources :variants
      resources :option_types do
        member do
          get :select
          get :remove
        end
        collection do
          get :available
          get :selected
        end
      end
      resources :taxons do
        member do
          get :select
          delete :remove
        end
        collection do
          post :available
          get  :selected
        end
      end
    end
    resources :option_types
    resources :properties do
      collection do
        get :filtered
      end
    end

    resources :prototypes do
      member do
        get :select
      end

      collection do
        get :available
      end
    end

    resource :inventory_settings
    resources :google_analytics

    resources :orders do
      member do
        put :fire
        get :fire
        post :resend
        get :history
        get :user
      end

      resources :adjustments
      resources :line_items
      resources :shipments do
        member do
          put :fire
        end
      end
      resources :return_authorizations do
        member do
          put :fire
        end
      end
      resources :payments do
        member do
          put :fire
        end
      end
    end

    resource :general_settings

    resources :taxonomies do
      member do
        get :get_children
      end

      resources :taxons
    end

    resources :reports, :only => [:index, :show] do
      collection do
        get :sales_total
      end
    end

    resources :shipments
    resources :shipping_methods
    resources :shipping_categories
    resources :tax_rates
    resource  :tax_settings
    resources :calculators
    resources :product_groups do
      resources :product_scopes
    end


    resources :trackers
    resources :payment_methods
    resources :mail_methods
  end

  match '/admin' => 'admin/orders#index', :as => :admin

  match '/content/cvv' => 'content#cvv'

  #RAILS3 TODO - we should disable this by default
  #match '/:controller(/:action(/:id(.:format)))'

  # a catchall route for "static" content (except paths with explicit extensions: .html, .ico, etc)
  #if Spree::Config.instance && Spree::Config.get(:use_content_controller)
    match '/*path' => 'content#show'
  #end
end
