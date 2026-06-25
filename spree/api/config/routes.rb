Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v3 do
      namespace :store do
        # Authentication
        post 'auth/login', to: 'auth#create'
        post 'auth/refresh', to: 'auth#refresh'
        post 'auth/logout', to: 'auth#logout'

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

        # Newsletter Subscriptions (guest-accessible: subscribe + verify by token)
        resources :newsletter_subscribers, only: [:create] do
          collection do
            post :verify
          end
        end

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

        # Mounts a read-only nested `translations` matrix on parents in the
        # Spree.translatable_resources registry. Writes go through the batch
        # endpoint (POST /translations/batch). One generic controller serves
        # every translatable model. See docs/plans/5.5-6.0-resource-translations-api.md.
        concern :translatable do
          resources :translations, only: [:index], controller: 'translations'
        end

        # Definitions are per resource type, not per instance.
        resources :custom_field_definitions

        # Translation discovery: the translatable-resources registry and the
        # store's supported locales. See docs/plans/5.5-6.0-resource-translations-api.md.
        resources :translatable_resources, only: [:index]
        resources :locales, only: [:index]

        # Atomic multi-record translation upsert (e.g. an option type + all its
        # option values in one save). Flat list of independent registry writes.
        post 'translations/batch', to: 'translations/batches#create'

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
        # Self-service profile updates (e.g. the admin's own UI language)
        patch 'me', to: 'me#update'

        # Store Settings
        resource :store, only: [:show, :update], controller: 'store'

        # Staff & access (invitations, admin users, roles, API keys)
        resources :admin_users, only: [:index, :show, :update, :destroy]
        resources :invitations, only: [:index, :show, :create, :destroy] do
          member do
            patch :resend
          end
        end
        resources :api_keys, only: [:index, :show, :create, :update, :destroy] do
          collection do
            get :current
          end
          member do
            patch :revoke
          end
        end
        resources :allowed_origins
        resources :webhook_endpoints do
          member do
            post :send_test
            patch :enable
            patch :disable
          end
          resources :deliveries, controller: 'webhook_deliveries', only: [:index, :show] do
            member do
              post :redeliver
            end
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
        resources :products, concerns: [:custom_fieldable, :translatable] do
          member do
            post :clone
          end
          collection do
            post :bulk_status_update
            post :bulk_add_to_categories
            post :bulk_remove_from_categories
            post :bulk_add_to_channels
            post :bulk_remove_from_channels
            post :bulk_add_tags
            post :bulk_remove_tags
            delete :bulk_destroy
          end
          resources :variants, controller: 'products/variants' do
            resources :media, controller: 'media', only: [:index, :create, :update, :destroy]
          end
          resources :media, controller: 'media', only: [:index, :create, :update, :destroy]
        end

        # Categories
        resources :categories, only: [:index, :show], concerns: [:custom_fieldable, :translatable]

        # Option Types (with nested option_values in payload)
        resources :option_types, concerns: [:custom_fieldable, :translatable]

        # Tax Categories
        resources :tax_categories

        # Markets
        resources :markets

        # Store Credit Categories (read-only — for store credit dropdowns)
        resources :store_credit_categories, only: [:index, :show]

        # Inventory
        resources :stock_locations
        resources :stock_reservations, only: [:index, :show]
        resources :stock_items, only: [:index, :show, :update, :destroy]
        resources :stock_transfers, only: [:index, :show, :create, :destroy]

        # Payment Methods
        resources :payment_methods do
          collection do
            get :types
          end
        end

        # Promotions, with nested actions/rules/coupon codes.
        resources :promotions do
          resources :promotion_actions, only: [:index, :show, :create, :update, :destroy]
          resources :promotion_rules, only: [:index, :show, :create, :update, :destroy]
          resources :coupon_codes, only: [:index, :show]
        end

        # Subclass discovery for the promotion editor: `/promotion_actions/types`
        # and `/promotion_rules/types` enumerate registered subclasses with
        # their preference schemas. Top-level so the SPA can build the
        # "Add action / Add rule" pickers without a parent promotion.
        get 'promotion_actions/types', to: 'promotion_actions#types'
        get 'promotion_rules/types',   to: 'promotion_rules#types'

        # Calculator catalog for actions that include CalculatedAdjustments
        # (CreateAdjustment, CreateItemAdjustments). Returns the registered
        # calculator subclasses for the given action type along with each
        # calculator's preference schema, so the SPA can render the picker
        # + nested calculator preferences.
        get 'promotion_actions/calculators', to: 'promotion_actions#calculators'

        # Tags (autocomplete for product/order/user tag inputs)
        resources :tags, only: [:index]

        # Customers
        resources :customers, concerns: :custom_fieldable do
          resources :addresses, controller: 'customers/addresses'
          resources :credit_cards, controller: 'customers/credit_cards', only: [:index, :show, :destroy]
          resources :store_credits, controller: 'customers/store_credits'

          collection do
            post :bulk_add_to_groups
            post :bulk_remove_from_groups
            post :bulk_add_tags
            post :bulk_remove_tags
          end
        end

        # Customer groups (segmentation; used by promotion rules + bulk customer ops)
        resources :customer_groups

        # Price lists
        resources :price_lists do
          collection do
            get :price_rule_types
          end
          member do
            patch :activate
            patch :deactivate
          end
        end

        # Prices (generic — covers base prices AND price-list overrides).
        resources :prices do
          collection do
            post :bulk_upsert
            delete :bulk_destroy
          end
        end

        # Gift cards
        resources :gift_cards
        resources :gift_card_batches, only: [:index, :show, :create]

        # Channels (per-store distribution surfaces)
        resources :channels do
          member do
            post :add_products
            post :remove_products
          end
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
