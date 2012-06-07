Spree::Core::Engine.routes.draw do

  root :to => 'home#index'

  resources :products

  match '/locale/set', :to => 'locale#set'

  resources :tax_categories

  resources :states, :only => :index

  # non-restful checkout stuff
  match '/checkout/update/:state', :to => 'checkout#update', :as => :update_checkout, :via => :put
  match '/checkout/:state', :to => 'checkout#edit', :as => :checkout_state, :via => :get
  match '/checkout', :to => 'checkout#edit', :state => 'address', :as => :checkout, :via => :get

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
  get '/cart', :to => 'orders#edit', :as => :cart
  put '/cart', :to => 'orders#update', :as => :update_cart
  put '/cart/empty', :to => 'orders#empty', :as => :empty_cart

  resources :shipments do
    member do
      get :shipping_method
      put :shipping_method
    end
  end

  #   # Search routes
  match 's/*product_group_query', :to => 'products#index', :as => :simple_search
  match '/pg/:product_group_name', :to => 'products#index', :as => :pg_search
  match '/t/*id/s/*product_group_query', :to => 'taxons#show', :as => :taxons_search
  match 't/*id/pg/:product_group_name', :to => 'taxons#show', :as => :taxons_pg_search

  #   # route globbing for pretty nested taxon and product paths
  match '/t/*id', :to => 'taxons#show', :as => :nested_taxons
  #
  #   #moved old taxons route to after nested_taxons so nested_taxons will be default route
  #   #this route maybe removed in the near future (no longer used by core)
  #   map.resources :taxons
  #

  namespace :admin do
    resources :adjustments
    resources :zones
    resources :users do
      member do
        post :dismiss_banner
      end
    end
    resources :countries do
      resources :states
    end
    resources :states
    resources :tax_categories
    resources :configurations, :only => :index
    resources :products do
      resources :product_properties
      resources :images do
        collection do
          post :update_positions
        end
      end
      member do
        get :clone
      end
      resources :variants do
        collection do
          post :update_positions
        end
      end
      resources :option_types do
        member do
          get :select
          get :remove
        end
        collection do
          get :available
          get :selected
          post :update_positions
        end
      end
      resources :taxons do
        member do
          get :select
          delete :remove
        end
        collection do
          post :available
          post :batch_select
          get  :selected
        end
      end
    end

    resources :option_types do
      collection do
        post :update_positions
      end
    end

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
      end

      resource :customer, :controller => "orders/customer_details"

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

    resource :general_settings do
      collection do
        post :dismiss_alert
      end
    end

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
    resources :mail_methods do
      member do
        post :testmail
      end
    end
  end

  match '/admin', :to => 'admin/orders#index', :as => :admin

  match '/content/cvv', :to => 'content#cvv'
  match '/content/*path', :to => 'content#show', :via => :get, :as => :content
end
