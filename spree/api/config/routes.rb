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

        # Current channel context (never a list — see Store::ChannelController)
        resource :channel, only: [:show], controller: 'channel'

        # Catalog
        resources :products, only: [:index, :show] do
          collection do
            get :filters, to: 'products/filters#index'
          end
        end
        # Public seller profiles. Read-only, and only sellers a shopper can
        # actually buy from — see Store::SellersController.
        resources :sellers, only: [:index, :show], id: /.+/

        resources :categories, only: [:index, :show], id: /.+/
        resources :collections, only: [:index, :show] do
          resources :products, controller: 'collections/products', only: [:index]
        end

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
          resource :tax_identifier, only: [:show, :update, :destroy], controller: 'carts/tax_identifiers'
        end

        # Delivery methods (pickup discovery)
        resources :delivery_methods, only: [:index, :show] do
          member do
            get :pickup_locations
            get :pickup_points
          end
        end

        # Orders (single order lookup, guest-accessible via order token)
        resources :orders, only: [:show] do
          # Customer self-service returns — opening and viewing only; the
          # merchant approves, receives and refunds through the Admin API.
          resources :returns, only: [:index, :show, :create], controller: 'orders/returns'
          resources :claims, only: [:index, :show, :create], controller: 'orders/claims'
          # Read-only — the registration frozen onto the order at completion.
          resource :tax_identifier, only: [:show], controller: 'orders/tax_identifiers'
        end

        # Policies (return policy, privacy policy, terms of service, etc.)
        resources :policies, only: [:index, :show]

        # Password Resets (top-level, no auth required)
        resources :password_resets, only: [:create, :update], controller: 'customer/password_resets'

        # Customers
        resources :customers, only: [:create]

        # Newsletter Subscriptions
        # - create + verify + request_unsubscribe are guest-accessible
        # - destroy accepts either an unsubscribe token (from email links) or JWT auth
        # A signed-in customer reads their own subscription (and its id) off the
        # `newsletter_subscriber` association on GET /customers/me.
        resources :newsletter_subscribers, only: [:create, :destroy] do
          collection do
            post :verify
            post :request_unsubscribe
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
          # Plural for the list a checkout page offers; singular for reading or
          # upserting one kind without knowing whether it exists yet.
          resources :tax_identifiers, only: [:index], controller: 'tax_identifiers'
          resource :tax_identifier, only: [:show, :update, :destroy], controller: 'tax_identifiers'
          resources :payment_setup_sessions, only: [:create, :show] do
            member do
              patch :complete
            end
          end
        end

        # Company self-service — the buyer's organization directory
        # (docs/plans/6.0-b2b-companies-and-catalogs.md). Authorization is
        # standing + the storefront access policy, never roles.
        get 'account/companies', to: 'account/companies#index'

        resources :companies, only: [:show, :update] do
          resources :addresses, only: [:index, :create, :update, :destroy],
                                controller: 'companies/addresses'
          # POST takes customer_email — a membership for an existing customer,
          # an invitation otherwise.
          resources :members, only: [:index, :create, :destroy], controller: 'companies/members'
          # DELETE revokes the invitation rather than erasing the record.
          resources :invitations, only: [:index, :destroy], controller: 'companies/invitations'
          # Completed purchases across the node's subtree.
          resources :orders, only: [:index], controller: 'companies/orders'
        end

        # The invitee has no company yet — and no account — so the token flow
        # is deliberately top-level and unauthenticated, unlike everything
        # else about a company, which is reached through the node.
        get 'company_invitations/:token', to: 'company_invitations#show', as: :company_invitation_lookup
        post 'company_invitations/:token/accept', to: 'company_invitations#accept'

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
        # Spree::HasCustomFields. See docs/plans/5.4-6.0-custom-fields-rename.md.
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
        resources :custom_field_definitions do
          collection do
            # What a definition can be attached to, from the registry.
            get :resource_types
          end
        end

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

        # Provider discovery + SSO callback — unauthenticated; both are used
        # before a session exists. Discovery drives the dashboard login page.
        get 'auth/providers', to: 'auth#providers'
        get 'auth/callback/:provider', to: 'auth#callback'

        # Public invitation acceptance — unauthenticated; the prefixed ID +
        # token in the URL act as the credential. Mounted under `auth/` so
        # the issued refresh-token cookie's path matches `/auth/refresh`.
        get 'auth/invitations/:id/lookup', to: 'invitation_acceptances#lookup'
        post 'auth/invitations/:id/accept', to: 'invitation_acceptances#accept'

        # First-run setup — unauthenticated; the one-time setup token is the
        # credential, and the flow self-disables once any admin user exists.
        get 'auth/setup', to: 'setup#show'
        get 'auth/setup/countries', to: 'setup#countries'
        post 'auth/setup', to: 'setup#create'

        # Public password reset — unauthenticated; the token is the credential.
        # Mounted under `auth/` so the refresh-token cookie issued on success
        # shares its path with `/auth/refresh`.
        post 'auth/password_resets', to: 'password_resets#create'
        patch 'auth/password_resets/:id', to: 'password_resets#update'

        # Dashboard
        namespace :dashboard do
          get :analytics
        end

        # Current admin user + permissions (for UI permission checks)
        get 'me', to: 'me#show'
        # Self-service profile updates (e.g. the admin's own UI language)
        patch 'me', to: 'me#update'

        # Store Settings
        resource :store, only: [:show, :update], controller: 'store' do
          get :data_sources
        end

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
        resources :roles, only: [:index, :show, :create, :update, :destroy]
        resources :permissions, only: [:index]

        # Direct Uploads (Active Storage)
        resources :direct_uploads, only: [:create]

        # CSV Exports — see docs/plans/5.5-admin-spa-csv-export.md
        resources :exports, only: [:index, :show, :create, :destroy] do
          member do
            get :download
          end
        end

        # CSV Imports — see docs/plans/5.6-admin-spa-csv-import.md
        resources :imports, only: [:index, :show, :create, :destroy] do
          collection do
            get :template
            get :example
          end
          member do
            patch :complete_mapping
            patch :retry_failed_rows
            get :download
          end
          resources :rows, only: [:index], controller: 'import_rows'
        end

        # Products
        resources :product_types do
          member do
            post :apply_to_products
          end
        end
        resources :products, concerns: [:custom_fieldable, :translatable] do
          member do
            post :clone
            # Closing a review a seller opened
            # (docs/plans/6.0-seller-product-submission.md).
            patch :approve
            patch :reject
          end
          collection do
            post :bulk_status_update
            post :bulk_add_to_categories
            post :bulk_remove_from_categories
            post :bulk_add_to_collections
            post :bulk_remove_from_collections
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

        # Media library — every file in the store, placed or not. Files are put
        # ON a product through the nested media routes above; this is where they
        # are uploaded, browsed and deleted.
        resources :media, controller: 'media_library', only: [:index, :show, :create, :update, :destroy] do
          member do
            get :usage
          end
        end

        # Categories
        resources :categories, concerns: [:custom_fieldable, :translatable] do
          member do
            patch :reposition
          end

          # Manual product membership + ordering within the category.
          # (Bulk add/remove reuse POST /products/bulk_{add,remove}_*_categories.)
          resources :products, controller: 'categories/products', only: [:index, :create, :destroy] do
            member do
              patch :reposition
            end
          end
        end

        # Collections (flat, merchandising). Reordering the collection itself is a
        # plain `position` update (acts_as_list reorders on save), so there is no
        # top-level reposition action — only the nested membership has one.
        resources :collections, concerns: [:custom_fieldable, :translatable] do
          # Manual product membership + ordering within the collection.
          resources :products, controller: 'collections/products', only: [:index, :create, :destroy] do
            member do
              patch :reposition
            end
          end
        end

        # Subclass discovery for the collection rules editor, mirroring
        # `/promotion_rules/types`. Top-level (and read-only) because rules are
        # written through the collection's own `rules` setter, not nested CRUD.
        get 'collection_rules/types', to: 'collection_rules#types'

        # Option Types (with nested option_values in payload)
        resources :option_types, concerns: [:custom_fieldable, :translatable]

        # Store policies (terms of service, privacy, returns, shipping, …)
        resources :policies, concerns: [:translatable]

        # Tax Categories
        resources :tax_categories

        # Tax Rates — the internal tax provider's configuration
        resources :tax_rates

        # Selectable tax engines and their declared limits (discovery only)
        resources :tax_providers, only: [:index]

        # Return / claim / refund reasons (dropdowns + settings management)
        resources :return_reasons
        resources :claim_reasons
        resources :refund_reasons

        # Markets
        resources :markets

        # Inventory
        resources :stock_locations
        resources :stock_reservations, only: [:index, :show]
        resources :stock_levels, only: [:index, :show, :update, :destroy] do
          collection do
            post :bulk_upsert
          end
        end
        resources :stock_movements, only: [:index, :show]
        resources :stock_transfers, only: [:index, :show, :create, :destroy]

        # Payment Methods
        resources :delivery_methods do
          collection do
            get :calculators
            get :fulfillment_providers
            get :rate_providers
          end
          resources :rules, controller: 'delivery_methods/rules', only: [:index, :show, :create, :update, :destroy]
        end
        resources :tracking_carriers, only: [:index]
        resources :delivery_method_rules, only: [] do
          collection do
            get :types
          end
        end
        resources :delivery_zones

        resources :delivery_profiles do
          collection do
            get :kinds
          end
          resources :origin_groups, controller: 'delivery_profiles/origin_groups',
                                    only: [:index, :show, :create, :update, :destroy]
        end

        resources :payment_methods do
          collection do
            get :types
          end
        end

        resources :integrations do
          collection do
            get :types
          end
          member do
            post :test
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
          resources :tax_identifiers, controller: 'customers/tax_identifiers' do
            member do
              post :validate
            end
          end

          collection do
            post :bulk_add_to_groups
            post :bulk_remove_from_groups
            post :bulk_add_tags
            post :bulk_remove_tags
          end
        end

        # Customer groups (segmentation; used by promotion rules + bulk customer ops)
        resources :customer_groups

        # Marketplace sellers. Each status change is its own member action
        # because each one is a workflow with its own arguments — mass
        # assignment would skip the mail and the extension hooks.
        resources :sellers, concerns: :custom_fieldable do
          member do
            post :invite
            patch :approve
            patch :suspend
            patch :reject
            # Where the seller stands against the marketplace's checklist,
            # and the way back to onboarding when something has to be redone.
            get :onboarding
            patch :reopen_onboarding
          end

          # Who runs this seller, and the offers nobody has accepted yet.
          # The operator is the only one who can repair a seller whose team
          # has locked itself out, which the seller's own panel cannot do.
          resources :team, only: [:index, :destroy], controller: 'sellers/team'
          resources :invitations, only: [:index, :destroy], controller: 'sellers/invitations' do
            member do
              patch :resend
            end
          end

          # What this seller submitted about the requirements, and the
          # operator's decisions on it. Nested, because a submission means
          # nothing outside the seller it belongs to.
          resources :requirement_submissions, only: [:index, :show, :create],
                                              controller: 'seller_requirement_submissions' do
            member do
              patch :accept
              patch :reject
              get :download
            end
          end
        end

        # What this marketplace asks of a seller before it will let them
        # trade. Configuration, so it hangs off the store rather than a
        # seller.
        resources :seller_requirements do
          collection do
            get :types
          end
        end

        # Commissions — what the marketplace charges its sellers. Rates are
        # configuration; lines are the record of what was charged, so they are
        # read-only.
        resources :commission_rates do
          collection do
            get :rule_types
          end
        end
        resources :commission_lines, only: [:index, :show]

        # What one checkout produced when it reached several sellers. Read-only:
        # everything an operator acts on lives on the orders inside it.
        resources :order_groups, only: [:index, :show]

        # Business customers — a tree of company nodes. Nested collections are
        # listed and created under their node and then addressed directly, so
        # a caller holding an entry id does not have to know its company.
        resources :companies do
          # The node's address book.
          resources :addresses, controller: 'companies/addresses'

          # The people with standing over the node. Creation takes an email:
          # a membership for an existing customer, an invitation otherwise.
          resources :memberships, controller: 'companies/memberships',
                                  only: [:index, :show, :create, :destroy]
          # DELETE revokes the invitation rather than erasing the record.
          resources :invitations, controller: 'companies/invitations',
                                  only: [:index, :show, :destroy]

          # The business's own registration — the number on its invoices, which
          # outranks the buyer's own. Same shape as the customer's.
          resources :tax_identifiers, controller: 'companies/tax_identifiers' do
            member do
              post :validate
            end
          end

          # Exemption evidence. Accepting or withdrawing one is its own action —
          # never mass assignment — and a verified certificate is revoked
          # rather than deleted.
          resources :tax_exemption_certificates, controller: 'companies/tax_exemption_certificates' do
            member do
              patch :verify
              patch :revoke
              get :download
            end
          end
        end


        # Catalogs — assortment + optional price list, assigned to an audience
        # (channel, customer group, market, or company subtree).
        resources :catalogs do
          member do
            post :assign
            post :import_products
          end
          # Manual assortment membership + ordering within the catalog.
          resources :products, controller: 'catalogs/products', only: [:index, :create, :destroy] do
            member do
              patch :reposition
            end
          end
        end
        resources :catalog_assignments, only: [:show, :destroy]

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

        # Post-sale, across all orders. Read-only — creating any of these
        # needs an order, so writes live under /orders/:order_id/...
        resources :returns, only: [:index, :show]
        resources :exchanges, only: [:index, :show]
        resources :claims, only: [:index, :show]

        # Channels (per-store distribution surfaces)
        resources :channels do
          member do
            post :add_products
            post :remove_products
          end

          resources :order_routing_rules, only: [:index, :show, :create, :update, :destroy]
        end

        # Subclass discovery for the routing-rules editor, mirroring
        # `/promotion_rules/types`. Top-level so the SPA can build the
        # "Add rule" picker without a parent channel.
        get 'order_routing_rules/types', to: 'order_routing_rules#types'

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
          resources :fulfillments, controller: 'orders/fulfillments', only: [:index, :show, :create, :update] do
            member do
              patch :fulfill
              patch :purchase_label
              patch :mark_delivered
              patch :cancel
              patch :resume
              patch :split
            end
          end
          resources :returns, controller: 'orders/returns', only: [:index, :show, :create, :update] do
            member do
              patch :approve
              patch :receive
              patch :refund
              patch :cancel
            end
          end
          resources :exchanges, controller: 'orders/exchanges', only: [:index, :show, :create, :update] do
            member do
              patch :approve
              patch :receive
              patch :fulfill
              patch :cancel
            end
          end
          resources :claims, controller: 'orders/claims', only: [:index, :show, :create, :update] do
            member do
              patch :approve
              patch :resolve
              patch :deny
              patch :cancel
            end
          end
          resources :payments, controller: 'orders/payments', only: [:index, :show, :create] do
            member do
              patch :capture
              patch :void
            end
          end
          resources :refunds, controller: 'orders/refunds', only: [:index, :create]
          resources :tax_lines, controller: 'orders/tax_lines', only: [:index, :show]
          # Read-only — the registration frozen onto the order at completion.
          resource :tax_identifier, controller: 'orders/tax_identifiers', only: [:show]
          resources :discounts, controller: 'orders/discounts', only: [:index, :show, :create, :update, :destroy]
          resources :discount_codes, controller: 'orders/discount_codes', only: [:create, :destroy]
          resources :fees, controller: 'orders/fees', only: [:index, :show, :create, :update, :destroy]
          resources :gift_cards, controller: 'orders/gift_cards', only: [:create, :destroy]
          resource :store_credits, controller: 'orders/store_credits', only: [:create, :destroy]
        end
      end

      # The marketplace seller panel. A branch of its own rather than a
      # narrowing of :admin — every endpoint here scope-fetches through
      # current_seller, which is what makes cross-seller access impossible by
      # construction rather than by rule.
      namespace :seller do
        # Everything unauthenticated lives under auth/, so the refresh
        # cookie's path covers it and nothing else.
        post 'auth/login', to: 'auth#create'
        post 'auth/refresh', to: 'auth#refresh'
        post 'auth/logout', to: 'auth#logout'
        get 'auth/providers', to: 'auth#providers'

        # Public invitation acceptance — unauthenticated; the prefixed ID +
        # token in the emailed link are the credential.
        get 'auth/invitations/:id/lookup', to: 'invitation_acceptances#lookup'
        post 'auth/invitations/:id/accept', to: 'invitation_acceptances#accept'

        # Public password reset — unauthenticated; the emailed token is the
        # credential. Under `auth/` so the refresh cookie issued on success
        # shares its path with `/auth/refresh`.
        post 'auth/password_resets', to: 'password_resets#create'
        patch 'auth/password_resets/:id', to: 'password_resets#update'

        get 'me', to: 'me#show'

        # Singular: the seller in play is always `current_seller`.
        resource :profile, only: [:show, :update], controller: 'profile'

        resources :team, only: [:index, :create, :destroy], controller: 'team'

        # Creating an invitation is hiring, so it lives on `team`; chasing or
        # withdrawing one is bookkeeping on the offer.
        resources :invitations, only: [:index, :destroy], controller: 'invitations' do
          member do
            patch :resend
          end
        end

        resources :products, only: [:index, :show, :create, :update, :destroy] do
          # Status moves are actions, not an attribute: putting a product on
          # sale is the marketplace's call, so a seller asks rather than sets.
          member do
            patch :submit
            patch :draft
            patch :archive
          end

          # The same three moves over a selection. Only the ones a seller may
          # make alone: there is no bulk route onto `active`, because reaching
          # it is the operator's decision on one listing at a time.
          collection do
            post :bulk_submit
            post :bulk_status_update
            delete :bulk_destroy
          end
        end


        # What this seller has sold. Cancelling is a member action because it
        # is a workflow with its own arguments, and fulfilling is nested: a
        # parcel means nothing outside the order it belongs to.
        resources :orders, only: [:index, :show] do
          member do
            patch :cancel
          end

          resources :fulfillments, only: [:index, :show], controller: 'orders/fulfillments' do
            member do
              patch :fulfill
            end
          end
        end

        resources :direct_uploads, only: [:create]

        # No destroy: a location holds stock levels and is named on historical
        # fulfillments, so a seller retires one by deactivating it.
        resources :stock_locations, only: [:index, :show, :create, :update]

        resources :countries, only: [:index]

        # The seller's own policy documents.
        resources :policies

        # Singular: the checklist is always `current_seller`'s.
        resource :onboarding, only: [:show], controller: 'onboarding' do
          post :submit_for_review
        end

        resources :requirements, only: [] do
          resources :submissions, only: [:create], controller: 'requirement_submissions'
        end
        resources :requirement_submissions, only: [] do
          member do
            get :download
          end
        end
      end

      # Webhooks (outside of store namespace — no API key authentication)
      namespace :webhooks do
        post 'payments/:payment_method_id', to: 'payments#create', as: :payment_webhook
        post 'fulfillments/:integration_id', to: 'fulfillments#create', as: :fulfillment_webhook
      end
    end
  end
end
