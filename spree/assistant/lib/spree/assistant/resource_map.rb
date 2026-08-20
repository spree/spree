module Spree
  module Assistant
    # What the generic read tools are allowed to look at.
    #
    # An allowlist rather than "any model": the assistant reaches store data
    # through the same relation the Admin API uses — `for_store`, which is how
    # every admin controller scopes its collection — and a model that is not
    # listed here simply does not exist as far as the assistant is concerned.
    #
    # Permissions mirror the controllers rather than inventing keys: the
    # catalog has no `read_price_lists`, and the price-lists controller rides
    # `read_products`, so this does too. Where a resource DOES have its own
    # key, it must use it — a looser key here would let an admin ask the
    # assistant for something the dashboard would refuse them. Enforced by a
    # spec that compares every entry against its controller's scoped_resource.
    class ResourceMap
      # A registered resource whose model has no store scoping. Raised rather
      # than quietly leaking another store's records.
      UnscopedResourceError = Class.new(StandardError)

      Entry = Struct.new(:key, :model_name, :permission, :serializer_name,
                         :dashboard_path, :scope_name, keyword_init: true) do
        # Where this record lives in the dashboard, so an answer links to it
        # rather than describing where to look. Store-relative — the panel
        # prefixes the current store segment.
        #
        # @param record [ActiveRecord::Base]
        # @return [String, nil]
        def dashboard_path_for(record)
          return if dashboard_path.blank?

          format(dashboard_path, id: record.prefixed_id)
        end

        # @return [Class]
        def model_class
          model_name.constantize
        end

        # Records of this kind the asking admin may see.
        #
        # Takes the context rather than the store so the ability filter cannot
        # be skipped by forgetting to apply it: store scoping answers tenancy,
        # `accessible` answers which records within that tenant — the same two
        # steps an Admin API controller takes.
        #
        # @param context [Spree::Assistant::Context]
        # @param action [Symbol]
        # @return [ActiveRecord::Relation]
        def scope_for(context, action = :show)
          relation = model_class.for_store(context.store)

          # `Spree::Base.for_store` falls back to the bare class when a model
          # has no matching Store association, returning EVERY store's rows.
          # A model that defines its own `for_store` has made a deliberate
          # choice (customers are global by design, and Spree::Customer says
          # so); inheriting the fallback is an accident. Only the accident is
          # refused, because serving another store's records to an assistant
          # that reads them aloud is worse than a missing resource.
          if model_class.method(:for_store).owner == Spree::Base.singleton_class && relation.equal?(model_class)
            raise UnscopedResourceError, key
          end

          # A resource that is a slice of a model rather than the whole of it
          # (draft orders among orders) narrows further.
          relation = relation.public_send(scope_name) if scope_name.present?

          context.accessible(relation, action)
        end

        # Whether this resource's scoping is deliberate — either a real
        # store relation, or a model that owns its `for_store` and has decided
        # it is global.
        #
        # @return [Boolean]
        def store_scoped?
          model_class.method(:for_store).owner != Spree::Base.singleton_class ||
            !model_class.for_store(Spree::Store.new).equal?(model_class)
        rescue StandardError
          false
        end

        # @return [Class] the admin serializer for this resource
        def serializer_class
          serializer_name.constantize
        end

        # Fields the model actually allows filtering and sorting on. Reused from
        # the model's own Ransack allowlist so the assistant can never query a
        # field the API would refuse.
        #
        # @return [Array<String>]
        def filterable_fields
          model_class.ransackable_attributes.sort
        end

        # Named queries the model exposes — `in_stock`, `out_of_stock`,
        # `price_lte` and so on. These answer the questions merchants actually
        # ask ("what's out of stock?") and cannot be expressed as an attribute
        # filter, because the answer lives across stock levels rather than in a
        # column. Passed as bare keys rather than `field_predicate` pairs.
        #
        # @return [Array<String>]
        def filterable_scopes
          model_class.ransackable_scopes.map(&:to_s).sort
        end
      end

      ENTRIES = [
        # Catalog
        Entry.new(key: 'products', model_name: 'Spree::Product',
                  permission: 'read_products', serializer_name: 'Spree::Api::V3::Admin::ProductSerializer',
                  dashboard_path: '/products/%<id>s'),
        Entry.new(key: 'categories', model_name: 'Spree::Category',
                  permission: 'read_categories', serializer_name: 'Spree::Api::V3::Admin::CategorySerializer',
                  dashboard_path: '/products/categories/%<id>s'),
        Entry.new(key: 'collections', model_name: 'Spree::Collection',
                  permission: 'read_collections', serializer_name: 'Spree::Api::V3::Admin::CollectionSerializer',
                  dashboard_path: '/products/collections/%<id>s'),
        # Price lists have no catalog key of their own; the Admin API rides
        # `read_products`, so this does too.
        Entry.new(key: 'price_lists', model_name: 'Spree::PriceList',
                  permission: 'read_products', serializer_name: 'Spree::Api::V3::Admin::PriceListSerializer',
                  dashboard_path: '/products/price-lists/%<id>s'),
        # Option types and stock transfers are deliberately absent. Neither
        # model has a Store association, so `for_store` falls through to the
        # unscoped class and would hand this store's assistant every store's
        # rows. They can be listed the moment their models are genuinely
        # store-scoped; until then a missing resource is better than a leaking
        # one.

        # Orders
        Entry.new(key: 'orders', model_name: 'Spree::Order',
                  permission: 'read_orders', serializer_name: 'Spree::Api::V3::Admin::OrderSerializer',
                  dashboard_path: '/orders/%<id>s'),
        Entry.new(key: 'draft_orders', model_name: 'Spree::Order', scope_name: :drafts,
                  permission: 'read_orders', serializer_name: 'Spree::Api::V3::Admin::OrderSerializer',
                  dashboard_path: '/orders/%<id>s'),

        # People. Customers are store-scoped through `for_store` — the same
        # relation the Admin API uses — rather than a Store association, which
        # they do not have.
        Entry.new(key: 'customers', model_name: 'Spree::Customer',
                  permission: 'read_customers', serializer_name: 'Spree::Api::V3::Admin::CustomerSerializer',
                  dashboard_path: '/customers/%<id>s'),
        Entry.new(key: 'customer_groups', model_name: 'Spree::CustomerGroup',
                  permission: 'read_customers', serializer_name: 'Spree::Api::V3::Admin::CustomerGroupSerializer'),
        Entry.new(key: 'companies', model_name: 'Spree::Company',
                  permission: 'read_customers', serializer_name: 'Spree::Api::V3::Admin::CompanySerializer',
                  dashboard_path: '/companies/%<id>s'),
        Entry.new(key: 'sellers', model_name: 'Spree::Seller',
                  permission: 'read_sellers', serializer_name: 'Spree::Api::V3::Admin::SellerSerializer',
                  dashboard_path: '/sellers/%<id>s'),


        # Settings. Configuration a merchant asks about ("which payment methods
        # are on?", "what markets do we sell to?") rather than transacts on.
        Entry.new(key: 'channels', model_name: 'Spree::Channel',
                  permission: 'read_settings', serializer_name: 'Spree::Api::V3::Admin::ChannelSerializer',
                  dashboard_path: '/settings/channels'),
        Entry.new(key: 'markets', model_name: 'Spree::Market',
                  permission: 'read_settings', serializer_name: 'Spree::Api::V3::Admin::MarketSerializer',
                  dashboard_path: '/settings/markets'),
        Entry.new(key: 'payment_methods', model_name: 'Spree::PaymentMethod',
                  permission: 'read_settings', serializer_name: 'Spree::Api::V3::Admin::PaymentMethodSerializer',
                  dashboard_path: '/settings/payment-methods'),
        Entry.new(key: 'delivery_methods', model_name: 'Spree::DeliveryMethod',
                  permission: 'read_delivery_methods', serializer_name: 'Spree::Api::V3::Admin::DeliveryMethodSerializer'),
        Entry.new(key: 'delivery_profiles', model_name: 'Spree::DeliveryProfile',
                  permission: 'read_settings', serializer_name: 'Spree::Api::V3::Admin::DeliveryProfileSerializer',
                  dashboard_path: '/settings/delivery-profiles'),
        Entry.new(key: 'delivery_zones', model_name: 'Spree::DeliveryZone',
                  permission: 'read_settings', serializer_name: 'Spree::Api::V3::Admin::DeliveryZoneSerializer'),
        Entry.new(key: 'stock_locations', model_name: 'Spree::StockLocation',
                  permission: 'read_stock', serializer_name: 'Spree::Api::V3::Admin::StockLocationSerializer',
                  dashboard_path: '/settings/stock-locations'),
        Entry.new(key: 'tax_categories', model_name: 'Spree::TaxCategory',
                  permission: 'read_settings', serializer_name: 'Spree::Api::V3::Admin::TaxCategorySerializer',
                  dashboard_path: '/settings/tax-categories'),
        Entry.new(key: 'tax_rates', model_name: 'Spree::TaxRate',
                  permission: 'read_settings', serializer_name: 'Spree::Api::V3::Admin::TaxRateSerializer',
                  dashboard_path: '/settings/tax-rates'),
        Entry.new(key: 'product_types', model_name: 'Spree::ProductType',
                  permission: 'read_product_types', serializer_name: 'Spree::Api::V3::Admin::ProductTypeSerializer',
                  dashboard_path: '/settings/product-types'),
        Entry.new(key: 'commission_rates', model_name: 'Spree::CommissionRate',
                  permission: 'read_commissions', serializer_name: 'Spree::Api::V3::Admin::CommissionRateSerializer',
                  dashboard_path: '/settings/commission-rates'),
        Entry.new(key: 'roles', model_name: 'Spree::Role',
                  permission: 'read_staff', serializer_name: 'Spree::Api::V3::Admin::RoleSerializer',
                  dashboard_path: '/settings/roles'),
        Entry.new(key: 'return_reasons', model_name: 'Spree::ReturnReason',
                  permission: 'read_settings', serializer_name: 'Spree::Api::V3::Admin::ReturnReasonSerializer',
                  dashboard_path: '/settings/reasons'),
        Entry.new(key: 'webhook_endpoints', model_name: 'Spree::WebhookEndpoint',
                  permission: 'read_webhooks', serializer_name: 'Spree::Api::V3::Admin::WebhookEndpointSerializer'),
        Entry.new(key: 'allowed_origins', model_name: 'Spree::AllowedOrigin',
                  permission: 'read_settings', serializer_name: 'Spree::Api::V3::Admin::AllowedOriginSerializer',
                  dashboard_path: '/settings/allowed-origins'),
        Entry.new(key: 'imports', model_name: 'Spree::Import',
                  permission: 'read_settings', serializer_name: 'Spree::Api::V3::Admin::ImportSerializer',
                  dashboard_path: '/settings/imports'),
        Entry.new(key: 'exports', model_name: 'Spree::Export',
                  permission: 'read_settings', serializer_name: 'Spree::Api::V3::Admin::ExportSerializer'),

        # Deliberately absent, and not for lack of a page:
        #   api_keys      — the serializer exposes `plaintext_token`, so
        #                   listing them would send live credentials to an AI
        #                   vendor.
        #   integrations  — same shape of risk; the preferences blob is where
        #                   every provider credential lives.
        #   staff, custom_field_definitions — neither model is store-scoped,
        #                   so `for_store` would return every store's rows.

        # Marketing
        Entry.new(key: 'promotions', model_name: 'Spree::Promotion',
                  permission: 'read_promotions', serializer_name: 'Spree::Api::V3::Admin::PromotionSerializer',
                  dashboard_path: '/promotions/%<id>s'),
        # Gift cards are deliberately absent. The serializer exposes `code`,
        # which is the bearer instrument itself — anyone holding it can spend
        # the balance — and every tool result is transmitted to a third-party
        # AI vendor and stored in chat history. Balances and expiry could be
        # answered by a purpose-built tool that never emits the code.
      ].freeze

      class << self
        # @return [Array<Entry>]
        def all
          ENTRIES
        end

        # @param key [String]
        # @return [Entry, nil]
        def find(key)
          ENTRIES.find { |entry| entry.key == key.to_s }
        end

        # Resources this admin may read, so the tool description lists only what
        # they can actually ask about.
        #
        # @param context [Spree::Assistant::Context]
        # @return [Array<Entry>]
        def available_for(context)
          ENTRIES.select { |entry| context.permitted?(entry.permission) }
        end
      end
    end
  end
end
