Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v3 do
      namespace :store do
        # Authentication
        post 'auth/login', to: 'auth#create'
        post 'auth/register', to: 'auth#register'
        post 'auth/refresh', to: 'auth#refresh'
        post 'auth/oauth/callback', to: 'auth#oauth_callback'

        # Store
        get 'store', to: 'stores#current'

        # Geography - countries include nested states from checkout zone
        resources :countries, only: [:index, :show]

        # Catalog
        resources :products, only: [:index, :show]
        resources :taxonomies, only: [:index, :show]
        resources :taxons, only: [:show], id: /.+/

        # Orders
        resources :orders do
          member do
            # State transitions
            patch :next       # Move to next checkout step
            patch :advance    # Advance through all steps
            patch :complete   # Complete the order
          end

          # Nested resources - all require order access
          resource :store_credits, only: [:create, :destroy], controller: 'orders/store_credits'
          resources :line_items, only: [:create, :update, :destroy], controller: 'orders/line_items'
          resources :promotions, only: [:create, :destroy], controller: 'orders/promotions'
          resources :payments, only: [:index, :show], controller: 'orders/payments'
          resources :payment_methods, only: [:index], controller: 'orders/payment_methods'
          resources :shipments, only: [:index, :show, :update], controller: 'orders/shipments'
        end

        # Customer
        get 'customers/me', to: 'customers#show'
        patch 'customers/me', to: 'customers#update'
        resources :addresses, only: [:index, :show, :create, :update, :destroy], path: 'customers/me/addresses'
        resources :credit_cards, only: [:index, :show, :destroy], path: 'customers/me/credit_cards'
        resources :payment_sources, only: [:index, :show, :destroy], path: 'customers/me/payment_sources'

        # Wishlists
        resources :wishlists do
          resources :items, only: [:create, :update, :destroy], controller: 'wishlist_items'
        end

        # Digital Downloads
        # Access via token in URL
        get 'digitals/:token', to: 'digitals#download', as: :digital_download
      end
    end
  end
end
