Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v3 do
      namespace :store do
        # Authentication
        post 'auth/login', to: 'auth#create'
        post 'auth/refresh', to: 'auth#refresh'
        post 'auth/logout', to: 'auth#logout'
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
        resources :categories, only: [:index, :show], id: /.+/

        # Carts
        resources :carts, only: [:index, :show, :create, :update, :destroy] do
          member do
            patch :associate
            post :complete
          end
          resources :items, only: [:create, :update, :destroy], controller: 'carts/items'
          resources :discount_codes, only: [:create, :destroy], controller: 'carts/discount_codes'
          resources :gift_cards, only: [:create, :destroy], controller: 'carts/gift_cards'
          resources :fulfillments, only: [:update], controller: 'carts/fulfillments'
          resources :payments, only: [:create], controller: 'carts/payments'
          resources :payment_sessions, only: [:create, :show, :update], controller: 'carts/payment_sessions' do
            member do
              patch :complete
            end
          end
          resource :store_credits, only: [:create, :destroy], controller: 'carts/store_credits'
        end

        # Orders (single order lookup, guest-accessible via order token)
        resources :orders, only: [:show]

        # Policies (return policy, privacy policy, terms of service, etc.)
        resources :policies, only: [:index, :show]

        # Password Resets (top-level, no auth required)
        resources :password_resets, only: [:create, :update], controller: 'customer/password_resets'

        # Customers
        resources :customers, only: [:create]

        # Current customer profile and nested resources (/customers/me/...)
        namespace :customer, path: 'customers/me' do
          get '/', action: :show, controller: '/spree/api/v3/store/customers'
          patch '/', action: :update, controller: '/spree/api/v3/store/customers'

          resources :orders, only: [:index, :show]
          resources :addresses, only: [:index, :show, :create, :update, :destroy]
          resources :credit_cards, only: [:index, :show, :destroy]
          resources :gift_cards, only: [:index, :show]
          resources :store_credits, only: [:index, :show]
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

        # Data Feeds (public, no auth required)
        resources :feeds, only: [:show], controller: 'data_feeds', param: :slug
      end

      # Webhooks (outside of store namespace — no API key authentication)
      namespace :webhooks do
        post 'payments/:payment_method_id', to: 'payments#create', as: :payment_webhook
      end
    end
  end
end
