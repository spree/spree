spree_path = Rails.application.routes.url_helpers.try(:spree_path, trailing_slash: true) || '/'

Rails.application.routes.draw do
  use_doorkeeper scope: "#{spree_path}/spree_oauth"
end

Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v1 do
      resources :promotions, only: [:show]

      resources :customer_returns, only: [:index]
      resources :reimbursements, only: [:index]

      resources :products do
        resources :images
        resources :variants
        resources :product_properties
      end

      concern :order_routes do
        member do
          put :approve
          put :cancel
          put :empty
          put :apply_coupon_code
        end

        resources :line_items
        resources :payments do
          member do
            put :authorize
            put :capture
            put :purchase
            put :void
            put :credit
          end
        end

        resources :addresses, only: [:show, :update]

        resources :return_authorizations do
          member do
            put :add
            put :cancel
            put :receive
          end
        end
      end

      resources :checkouts, only: [:update], concerns: :order_routes do
        member do
          put :next
          put :advance
        end
      end

      resources :variants do
        resources :images
      end

      resources :option_types do
        resources :option_values
      end
      resources :option_values

      resources :option_values, only: :index

      get '/orders/mine', to: 'orders#mine', as: 'my_orders'
      get '/orders/current', to: 'orders#current', as: 'current_order'

      resources :orders, concerns: :order_routes do
        put :remove_coupon_code, on: :member
      end

      resources :zones
      resources :countries, only: [:index, :show] do
        resources :states, only: [:index, :show]
      end

      resources :shipments, only: [:create, :update] do
        collection do
          post 'transfer_to_location'
          post 'transfer_to_shipment'
          get :mine
        end

        member do
          put :ready
          put :ship
          put :add
          put :remove
        end
      end
      resources :states, only: [:index, :show]

      resources :taxonomies do
        member do
          get :jstree
        end
        resources :taxons do
          member do
            get :jstree
          end
        end
      end

      resources :taxons, only: [:index]

      resources :inventory_units, only: [:show, :update]

      resources :users do
        resources :credit_cards, only: [:index]
      end

      resources :properties
      resources :stock_locations do
        resources :stock_movements
        resources :stock_items
      end

      resources :stock_items, only: [:index, :update, :destroy]
      resources :stores

      put '/classifications', to: 'classifications#update', as: :classifications
      get '/taxons/products', to: 'taxons#products', as: :taxon_products
    end

    namespace :v2 do
      namespace :storefront do
        resource :cart, controller: :cart, only: %i[show create] do
          post   :add_item
          patch  :empty
          delete 'remove_line_item/:line_item_id', to: 'cart#remove_line_item', as: :cart_remove_line_item
          patch  :set_quantity
          patch  :apply_coupon_code
          delete 'remove_coupon_code/:coupon_code', to: 'cart#remove_coupon_code', as: :cart_remove_coupon_code
          delete 'remove_coupon_code', to: 'cart#remove_coupon_code', as: :cart_remove_coupon_code_without_code
          get :estimate_shipping_rates
        end

        resource :checkout, controller: :checkout, only: %i[update] do
          patch :next
          patch :advance
          patch :complete
          post :add_store_credit
          post :remove_store_credit
          get :payment_methods
          get :shipping_rates
        end

        resource :account, controller: :account, only: %i[show]

        namespace :account do
          resources :addresses, controller: :addresses
          resources :credit_cards, controller: :credit_cards, only: %i[index show]
          resources :orders, controller: :orders, only: %i[index show]
        end

        resources :countries, only: %i[index]
        get '/countries/:iso', to: 'countries#show', as: :country
        get '/order_status/:number', to: 'order_status#show', as: :order_status
        resources :products, only: %i[index show]
        resources :taxons,   only: %i[index show], id: /.+/
        get '/stores/:code', to: 'stores#show', as: :store
      end

      namespace :platform do
        # Promotions API
        resources :promotions

        # Returns API
        resources :customer_returns
        resources :reimbursements
        resources :return_authorizations do
          member do
            put :add
            put :cancel
            put :receive
          end
        end

        # Product Catalog API
        resources :products
        resources :images
        resources :variants
        resources :properties
        resources :product_properties
        resources :taxonomies do
          member do
            get :jstree
          end
        end
        resources :taxons do
          member do
            get :jstree
          end
        end
        resources :option_types
        resources :option_values

        # Order API
        resources :orders do
          member do
            put :next
            put :advance
            put :approve
            put :cancel
            put :empty
            put :apply_coupon_code
            put :remove_coupon_code
          end
        end
        resources :line_items
        resources :payments do
          member do
            put :authorize
            put :capture
            put :purchase
            put :void
            put :credit
          end
        end

        # Geo API
        resources :zones
        resources :countries
        resources :states

        # Shipment API
        resources :shipments do
          collection do
            post 'transfer_to_location'
            post 'transfer_to_shipment'
          end
          member do
            put :ready
            put :ship
            put :add
            put :remove
          end
        end

        # Inventory API
        resources :inventory_units
        resources :stock_items
        resources :stock_locations
        resources :stock_movements

        # User API
        resources :users
        resources :credit_cards
        resources :addresses

        # Store API
        resources :stores
      end
    end

    get '/404', to: 'errors#render_404'

    match 'v:api/*path', to: redirect { |params, request|
      format = ".#{params[:format]}" unless params[:format].blank?
      query  = "?#{request.query_string}" unless request.query_string.blank?

      if request.path == "#{spree_path}api/v1/#{params[:path]}#{format}#{query}"
        "#{spree_path}api/404"
      else
        "#{spree_path}api/v1/#{params[:path]}#{format}#{query}"
      end
    }, via: [:get, :post, :put, :patch, :delete]

    match '*path', to: redirect { |params, request|
      format = ".#{params[:format]}" unless params[:format].blank?
      query  = "?#{request.query_string}" unless request.query_string.blank?

      if request.path == "#{spree_path}api/v1/#{params[:path]}#{format}#{query}"
        "#{spree_path}api/404"
      else
        "#{spree_path}api/v1/#{params[:path]}#{format}#{query}"
      end
    }, via: [:get, :post, :put, :patch, :delete]
  end
end
