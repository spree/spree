Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v3 do
      namespace :store do
        # Authentication
        post 'auth/login', to: 'auth#create'
        post 'auth/refresh', to: 'auth#refresh'
        post 'auth/oauth/callback', to: 'auth#oauth_callback'

        # Customer registration
        resources :customers, only: [:create]

        # Markets
        resources :markets, only: [:index, :show] do
          collection do
            get :resolve
          end
          resources :countries, only: [:index, :show], controller: 'markets/countries'
        end

        # Countries, Currencies, Locales (flat, market-aware)
        resources :countries, only: [:index, :show]
        resources :currencies, only: [:index]
        resources :locales, only: [:index]

        # Catalog
        resources :products, only: [:index, :show] do
          collection do
            get :filters, to: 'products/filters#index'
          end
        end
        resources :categories, only: [:index, :show], id: /.+/ do
          resources :products, only: [:index], controller: 'categories/products'
        end

        # Cart
        resource :cart, only: [:show, :create], controller: 'cart' do
          patch :associate
        end

        # Orders - individual order management and checkout
        resources :orders, only: [:show, :update] do
          member do
            # State transitions
            patch :next       # Move to next checkout step
            patch :advance    # Advance through all steps
            patch :complete   # Complete the order
          end

          # Nested resources - all require order access
          resource :store_credits, only: [:create, :destroy], controller: 'orders/store_credits'
          resources :line_items, only: [:create, :update, :destroy], controller: 'orders/line_items'
          resources :coupon_codes, only: [:create, :destroy], controller: 'orders/coupon_codes'
          resources :payments, only: [:index, :show], controller: 'orders/payments'
          resources :payment_methods, only: [:index], controller: 'orders/payment_methods'
          resources :payment_sessions, only: [:create, :show, :update], controller: 'orders/payment_sessions' do
            member do
              patch :complete
            end
          end
          resources :shipments, only: [:index, :show, :update], controller: 'orders/shipments'
        end

        # Customer (current user profile)
        get 'customer', to: 'customers#show'
        patch 'customer', to: 'customers#update'

        # Customer nested resources
        namespace :customer, path: 'customer' do
          resources :addresses, only: [:index, :show, :create, :update, :destroy] do
            member do
              patch :mark_as_default
            end
          end
          resources :orders, only: [:index]
          resources :credit_cards, only: [:index, :show, :destroy]
          resources :gift_cards, only: [:index, :show]
          resources :payment_setup_sessions, only: [:create, :show] do
            member do
              patch :complete
            end
          end
        end

        # Wishlists
        resources :wishlists do
          resources :items, only: [:create, :update, :destroy], controller: 'wishlist_items'
        end

        # Digital Downloads
        # Access via token in URL
        get 'digitals/:token', to: 'digitals#show', as: :digital_download

      end

      namespace :admin do
        # Products
        resources :products do
          member do
            post :clone
          end
          resources :variants, controller: 'products/variants'
          resources :assets, controller: 'products/assets', only: [:index, :create, :update, :destroy]
        end

        # Taxonomies > Taxons
        resources :taxonomies do
          resources :taxons, controller: 'taxonomies/taxons'
        end

        # Taxons (flat, top-level)
        resources :taxons, only: [:index, :show]

        # Option Types (with nested option_values in payload)
        resources :option_types

        # Orders
        resources :orders do
          member do
            patch :next
            patch :advance
            patch :complete
            patch :cancel
            patch :approve
            patch :resume
            post :resend_confirmation
          end

          resources :line_items, controller: 'orders/line_items'
          resources :shipments, controller: 'orders/shipments', only: [:index, :show, :update] do
            member do
              patch :ship
              patch :cancel
              patch :resume
              patch :split
            end
          end
          resources :payments, controller: 'orders/payments', only: [:index, :show, :create] do
            member do
              patch :capture
              patch :void
            end
          end
          resources :refunds, controller: 'orders/refunds', only: [:index, :create]
          resources :adjustments, controller: 'orders/adjustments', only: [:index, :show, :create, :update, :destroy]
        end
      end
    end
  end
end
