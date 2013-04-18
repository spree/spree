Spree::Core::Engine.routes.draw do
  root :to => 'home#index'

  resources :products

  match '/locale/set', :to => 'locale#set'

  resources :states, :only => :index
  resources :countries, :only => :index

  # non-restful checkout stuff
  put '/checkout/update/:state', :to => 'checkout#update', :as => :update_checkout
  get '/checkout/:state', :to => 'checkout#edit', :as => :checkout_state
  get '/checkout', :to => 'checkout#edit' , :as => :checkout

  populate_redirect = redirect do |params, request|
    request.flash[:error] = I18n.t(:populate_get_error)
    request.referer || '/cart'
  end

  get '/orders/populate', :via => :get, :to => populate_redirect
  match '/orders/:id/token/:token' => 'orders#show', :via => :get, :as => :token_order

  resources :orders do
    post :populate, :on => :collection

    resources :line_items
  end

  get '/cart', :to => 'orders#edit', :as => :cart
  put '/cart', :to => 'orders#update', :as => :update_cart
  put '/cart/empty', :to => 'orders#empty', :as => :empty_cart

  # route globbing for pretty nested taxon and product paths
  match '/t/*id', :to => 'taxons#show', :as => :nested_taxons

  namespace :admin do
    get '/search/users', :to => "search#users", :as => :search_users

    resources :promotions do
      resources :promotion_rules
      resources :promotion_actions
    end

    resources :adjustments
    resources :zones
    resources :banners do
      member do
        post :dismiss
      end
    end
    resources :countries do
      resources :states
    end
    resources :states
    resources :tax_categories

    resources :products do
      resources :product_properties do
        collection do
          post :update_positions
        end
      end
      resources :images do
        collection do
          post :update_positions
        end
      end
      member do
        get :clone
        get :stock
      end
      resources :variants do
        collection do
          post :update_positions
        end
      end
    end

    get '/variants/search', :to => "variants#search", :as => :search_variants

    resources :option_types do
      collection do
        post :update_positions
        post :update_values_positions
      end
    end

    delete '/option_values/:id', :to => "option_values#destroy", :as => :option_value

    resources :properties do
      collection do
        get :filtered
      end
    end

    delete '/product_properties/:id', :to => "product_properties#destroy", :as => :product_property

    resources :prototypes do
      member do
        get :select
      end

      collection do
        get :available
      end
    end

    resource :image_settings

    resources :orders, :except => [:show] do
      member do
        put :fire
        get :fire
        post :resend
        get :open_adjustments
        get :close_adjustments
      end

      resource :customer, :controller => "orders/customer_details"

      resources :adjustments do
        member do
          get :toggle_state
        end
      end
      resources :line_items
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
      collection do
      	post :update_positions
      end
      member do
        get :get_children
      end
      resources :taxons
    end

    resources :taxons, :only => [] do
      collection do
        get :search
      end
    end

    resources :reports, :only => [:index, :show] do
      collection do
        get :sales_total
        post :sales_total
      end
    end

    resources :shipping_methods
    resources :shipping_categories
    resources :stock_transfers, :only => [:index, :show, :new, :create]
    resources :stock_locations do
      resources :stock_movements
      collection do
        post :transfer_stock
      end
    end

    resources :stock_movements
    resources :stock_items, :only => :update
    resources :tax_rates
    resource  :tax_settings

    resources :trackers
    resources :payment_methods
    resource :mail_method, :only => [:edit, :update] do
      post :testmail, :on => :collection
    end
  end

  match '/admin', :to => 'admin/orders#index', :as => :admin
end
