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
        resources :products, only: [:index, :show] do
          collection do
            get :filters, to: 'products/filters#index'
          end
        end
        resources :taxonomies, only: [:index, :show]
        resources :taxons, only: [:index, :show], id: /.+/ do
          resources :products, only: [:index], controller: 'taxons/products'
        end

        # Cart - alias for current incomplete order (creates if none exists)
        get 'cart', to: 'cart#show'
        patch 'cart/associate', to: 'cart#associate'

        # Orders - all orders (complete and incomplete)
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
          resources :coupon_codes, only: [:create, :destroy], controller: 'orders/coupon_codes'
          resources :payments, only: [:index, :show], controller: 'orders/payments'
          resources :payment_methods, only: [:index], controller: 'orders/payment_methods'
          resources :shipments, only: [:index, :show, :update], controller: 'orders/shipments'
        end

        # Customer
        namespace :customer, path: 'customer' do
          get '/', to: 'account#show'
          patch '/', to: 'account#update'
          resources :addresses, only: [:index, :show, :create, :update, :destroy]
          resources :credit_cards, only: [:index, :show, :destroy]
          resources :payment_sources, only: [:index, :show, :destroy]
        end

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
