spree_path = Rails.application.routes.url_helpers.try(:spree_path, trailing_slash: true) || '/'

Rails.application.routes.draw do
  use_doorkeeper scope: "#{spree_path}/spree_oauth"
end

Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v2 do
      namespace :storefront do
        resource :cart, controller: :cart, only: %i[show create destroy] do
          post   :add_item
          patch  :empty
          delete 'remove_line_item/:line_item_id', to: 'cart#remove_line_item', as: :cart_remove_line_item
          patch  :set_quantity
          patch  :apply_coupon_code
          delete 'remove_coupon_code/:coupon_code', to: 'cart#remove_coupon_code', as: :cart_remove_coupon_code, constraints: { coupon_code: /[^\/]+/ }
          delete 'remove_coupon_code', to: 'cart#remove_coupon_code', as: :cart_remove_coupon_code_without_code
          get :estimate_shipping_rates
          patch :associate
          patch :change_currency
        end

        resource :checkout, controller: :checkout, only: %i[update] do
          patch :next
          patch :advance
          patch :complete
          post :create_payment
          post :add_store_credit
          post :remove_store_credit
          get :payment_methods
          get :shipping_rates
          patch :select_shipping_method
          post :validate_order_for_payment
        end

        resource :account, controller: :account, only: %i[show create update]

        namespace :account do
          resources :addresses, controller: :addresses
          resources :credit_cards, controller: :credit_cards, only: %i[index show destroy]
          resources :orders, controller: :orders, only: %i[index show]
        end

        resources :countries, only: %i[index]
        get '/countries/:iso', to: 'countries#show', as: :country
        get '/order_status/:number', to: 'order_status#show', as: :order_status
        resources :products, only: %i[index show]
        get '/products/:id/variants', to: 'variants#index', as: :product_variants
        resources :taxons,   only: %i[index show], id: /.+/
        get '/stores/:code', to: 'stores#show', as: :store
        get '/store', to: 'stores#current', as: :current_store

        resources :menus, only: %i[index show]
        resources :cms_pages, only: %i[index show]
        resources :policies, only: %i[index show]

        resources :wishlists do
          get :default, on: :collection

          member do
            post :add_item
            patch 'set_item_quantity/:item_id', to: 'wishlists#set_item_quantity', as: :set_item_quantity
            delete 'remove_item/:item_id', to: 'wishlists#remove_item', as: :remove_item
            post :add_items
            delete :remove_items
          end
        end

        resources :posts, only: %i[index show]
        resources :post_categories, only: %i[index show]

        get '/digitals/:token', to: 'digitals#download', as: 'digital'
      end

      namespace :platform do
        # Promotions API
        resources :promotions
        resources :promotion_actions
        resources :promotion_categories
        resources :promotion_rules

        # Returns API
        resources :customer_returns
        resources :reimbursements
        resources :return_authorizations do
          member do
            patch :add
            patch :cancel
            patch :receive
          end
        end

        # Product Catalog API
        resources :products
        resources :taxonomies
        resources :taxons do
          member do
            patch :reposition
          end
        end
        resources :classifications
        resources :images
        resources :variants
        resources :properties
        resources :product_properties
        resources :option_types
        resources :option_values

        # Order API
        resources :orders do
          member do
            patch :next
            patch :advance
            patch :approve
            patch :cancel
            patch :empty
            patch :apply_coupon_code
            patch :complete
            patch :use_store_credit
            patch :cancel
            patch :approve
          end
        end
        resources :line_items
        resources :adjustments

        # Payments API
        resources :payments do
          # TODO: support custom actions
          # member do
          #   patch :authorize
          #   patch :capture
          #   patch :purchase
          #   patch :void
          #   patch :credit
          # end
        end

        # Store Credit API
        resources :store_credits
        resources :store_credit_categories
        resources :store_credit_types

        # Geo API
        resources :zones
        resources :countries, only: [:index, :show]
        resources :states, only: [:index, :show]

        # Shipment API
        resources :shipments do
          member do
            %w[ready ship cancel resume pend].each do |state|
              patch state.to_sym
            end
            patch :add_item
            patch :remove_item
            patch :transfer_to_location
            patch :transfer_to_shipment
          end
        end

        # Tax API
        resources :tax_rates
        resources :tax_categories

        # Inventory API
        resources :inventory_units
        resources :stock_items
        resources :stock_locations
        resources :stock_movements

        # User API
        resources :users
        resources :credit_cards
        resources :addresses

        resources :roles

        # CMS
        resources :cms_pages
        resources :cms_sections

        # Wishlists API
        resources :wishlists
        resources :wished_items

        # Digitals API
        resources :digitals
        resources :digital_links do
          member do
            patch :reset
          end
        end

        # Store API
        resources :stores

        # Data Feeds API
        resources :data_feeds

        # Configurations API
        resources :payment_methods
        resources :shipping_categories
        resources :shipping_methods

        # Webhooks API
        namespace :webhooks do
        end

        # Gift Cards API
        resources :gift_cards
      end

      namespace :data_feeds do
        # google data feed API
        get '/google/:slug', to: 'google#rss_feed'
      end
    end

    namespace :v3 do
      namespace :storefront do
        # ===== AUTHENTICATION =====
        # Public endpoints for login/register, JWT required for refresh
        post 'auth/login', to: 'auth#create'
        post 'auth/register', to: 'auth#register'
        post 'auth/refresh', to: 'auth#refresh'
        post 'auth/oauth/callback', to: 'auth#oauth_callback'

        # ===== STORE & CONFIGURATION (Public) =====
        get 'store', to: 'stores#current'
        resources :stores, only: [:show], param: :code

        # Geography
        resources :countries, only: [:index, :show] do
          resources :states, only: [:index, :show]
        end

        # ===== CATALOG (Public) =====
        # Products with Ransack filtering
        # GET /products?q[name_cont]=shirt&q[s]=price+asc
        resources :products, only: [:index, :show] do
          resources :variants, only: [:index, :show]
        end

        # Taxons (categories)
        resources :taxons, only: [:index, :show]

        # ===== ORDERS (Public create, token or JWT for access) =====
        # POST /orders - Create order (returns order_token for guests)
        # Access via X-Order-Token header OR JWT
        resources :orders do
          # State transitions
          member do
            patch :next       # Move to next checkout step
            patch :advance    # Advance through all steps
            patch :complete   # Complete the order
            patch :cancel     # Cancel the order
          end

          # Nested resources - all require order access
          resources :line_items, only: [:index, :create, :show, :update, :destroy]
          resources :payments, only: [:index, :create, :show]
          resources :shipments, only: [:index, :show, :update]
          resources :coupon_codes, only: [:create, :destroy]

          # Available methods for order
          resources :shipping_methods, only: [:index]
          resources :payment_methods, only: [:index]

          # Addresses as nested resources
          resource :billing_address, only: [:show, :update], controller: 'order_addresses', defaults: { address_type: 'billing' }
          resource :shipping_address, only: [:show, :update], controller: 'order_addresses', defaults: { address_type: 'shipping' }
        end

        # ===== CUSTOMER (JWT Required) =====
        get 'customers/me', to: 'customers#show'
        patch 'customers/me', to: 'customers#update'

        resources :addresses, only: [:index, :show, :create, :update, :destroy], path: 'customers/me/addresses'
        resources :payment_sources, only: [:index, :show, :destroy], path: 'customers/me/payment_sources'

        # ===== WISHLISTS (JWT Required) =====
        resources :wishlists do
          get :default, on: :collection  # Get or create default wishlist

          # Wishlist items as nested resource
          resources :items, only: [:index, :create, :update, :destroy], controller: 'wishlist_items'
        end

        # ===== CMS & CONTENT (Public) =====
        resources :posts, only: [:index, :show]
        resources :policies, only: [:index, :show]

        # Pages (new page builder)
        resources :pages, only: [:index, :show] do
          resources :sections, only: [:index, :show]
        end

        # ===== DIGITAL DOWNLOADS =====
        # Access via token in URL
        get 'digitals/:token', to: 'digitals#download', as: :digital_download
      end
    end
  end
end
