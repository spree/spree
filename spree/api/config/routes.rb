Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v3 do
      namespace :store do
        # Authentication
        post 'auth/login', to: 'auth#create'
        post 'auth/refresh', to: 'auth#refresh'
        post 'auth/oauth/callback', to: 'auth#oauth_callback'

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

        # Carts (list all active carts for authenticated users)
        resources :carts, only: [:index]

        # Cart (pre-purchase, mutable)
        resource :cart, only: [:show, :create, :destroy], controller: 'cart' do
          patch :associate
          resources :items, only: [:create, :update, :destroy], controller: 'cart/items'
          resources :coupon_codes, only: [:create, :destroy], controller: 'cart/coupon_codes'
        end

        # Checkout (cart → order transition)
        resource :checkout, only: [:update], controller: 'checkout' do
          post :complete
          resources :shipments, only: [:index, :update], controller: 'checkout/shipments'
          resources :payment_methods, only: [:index], controller: 'checkout/payment_methods'
          resources :payments, only: [:index, :show, :create], controller: 'checkout/payments'
          resources :payment_sessions, only: [:create, :show, :update], controller: 'checkout/payment_sessions' do
            member do
              patch :complete
            end
          end
          resource :store_credits, only: [:create, :destroy], controller: 'checkout/store_credits'
        end

        # Orders (single order lookup, guest-accessible via order token)
        resources :orders, only: [:show]

        # Customer (current user profile)
        resources :customers, only: [:create]
        get 'customer', to: 'customers#show'
        patch 'customer', to: 'customers#update'

        # Customer nested resources
        namespace :customer, path: 'customer' do
          resources :orders, only: [:index, :show]
          resources :addresses, only: [:index, :show, :create, :update, :destroy] do
            member do
              patch :mark_as_default
            end
          end
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
    end
  end
end
