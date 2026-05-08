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

      namespace :admin do
        # Mounts a nested `custom_fields` resource on parents that include
        # Spree::Metafields. See docs/plans/5.4-6.0-custom-fields-rename.md.
        concern :custom_fieldable do
          resources :custom_fields
        end

        # Definitions are per resource type, not per instance.
        resources :custom_field_definitions

        # Authentication
        post 'auth/login', to: 'auth#create'
        post 'auth/refresh', to: 'auth#refresh'
        post 'auth/logout', to: 'auth#logout'

        # Public invitation acceptance — unauthenticated; the prefixed ID +
        # token in the URL act as the credential. Mounted under `auth/` so
        # the issued refresh-token cookie's path matches `/auth/refresh`.
        get 'auth/invitations/:id/lookup', to: 'invitation_acceptances#lookup'
        post 'auth/invitations/:id/accept', to: 'invitation_acceptances#accept'

        # Dashboard
        namespace :dashboard do
          get :analytics
        end

        # Current admin user + permissions (for UI permission checks)
        get 'me', to: 'me#show'

        # Store Settings
        resource :store, only: [:show, :update], controller: 'store'

        # Staff & access (invitations, admin users, roles, API keys)
        resources :admin_users, only: [:index, :show, :update, :destroy]
        resources :invitations, only: [:index, :show, :create, :destroy] do
          member do
            patch :resend
          end
        end
        resources :api_keys, only: [:index, :show, :create, :destroy] do
          member do
            patch :revoke
          end
        end
        resources :roles, only: [:index, :show]

        # Direct Uploads (Active Storage)
        resources :direct_uploads, only: [:create]

        # CSV Exports — see docs/plans/5.5-admin-spa-csv-export.md
        resources :exports, only: [:index, :show, :create, :destroy] do
          member do
            get :download
          end
        end

        # Products
        resources :products, concerns: :custom_fieldable do
          member do
            post :clone
          end
          resources :variants, controller: 'products/variants' do
            resources :media, controller: 'media', only: [:index, :create, :update, :destroy]
          end
          resources :media, controller: 'media', only: [:index, :create, :update, :destroy]
        end

        # Categories
        resources :categories, only: [:index, :show], concerns: :custom_fieldable

        # Option Types (with nested option_values in payload)
        resources :option_types, concerns: :custom_fieldable

        # Tax Categories
        resources :tax_categories, only: [:index, :show]

        # Stock Locations
        resources :stock_locations

        # Payment Methods
        resources :payment_methods, only: [:index, :show]

        # Tags (autocomplete for product/order/user tag inputs)
        resources :tags, only: [:index]

        # Customers
        resources :customers, concerns: :custom_fieldable do
          resources :addresses, controller: 'customers/addresses'
          resources :credit_cards, controller: 'customers/credit_cards', only: [:index, :show, :destroy]
          resources :store_credits, controller: 'customers/store_credits'
        end

        # Variants (top-level, for search/autocomplete across all products)
        resources :variants, only: [:index, :show], concerns: :custom_fieldable

        # Countries (with ?expand=states for state/province dropdown)
        resources :countries, only: [:index, :show]

        # Orders
        resources :orders, concerns: :custom_fieldable do
          member do
            patch :complete
            patch :cancel
            patch :approve
            patch :resume
            post :resend_confirmation
          end

          resources :items, only: [:index, :show, :create, :update, :destroy], controller: 'orders/items'
          resources :fulfillments, controller: 'orders/fulfillments', only: [:index, :show, :update] do
            member do
              patch :fulfill
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
          resources :adjustments, controller: 'orders/adjustments', only: [:index, :show]
          resources :gift_cards, controller: 'orders/gift_cards', only: [:create, :destroy]
          resource :store_credits, controller: 'orders/store_credits', only: [:create, :destroy]
        end
      end

      # Webhooks (outside of store namespace — no API key authentication)
      namespace :webhooks do
        post 'payments/:payment_method_id', to: 'payments#create', as: :payment_webhook
      end
    end
  end
end
