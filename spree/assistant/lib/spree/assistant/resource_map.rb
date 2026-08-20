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
    # `read_products`, so this does too.
    class ResourceMap
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
          # A resource that is a slice of a model rather than the whole of it
          # (draft orders among orders) narrows further.
          relation = relation.public_send(scope_name) if scope_name.present?

          context.accessible(relation, action)
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
                  permission: 'read_products', serializer_name: 'Spree::Api::V3::Admin::CategorySerializer',
                  dashboard_path: '/products/categories/%<id>s'),
        Entry.new(key: 'collections', model_name: 'Spree::Collection',
                  permission: 'read_products', serializer_name: 'Spree::Api::V3::Admin::CollectionSerializer',
                  dashboard_path: '/products/collections/%<id>s'),
        # Price lists have no catalog key of their own; the Admin API rides
        # `read_products`, so this does too.
        Entry.new(key: 'price_lists', model_name: 'Spree::PriceList',
                  permission: 'read_products', serializer_name: 'Spree::Api::V3::Admin::PriceListSerializer',
                  dashboard_path: '/products/price-lists/%<id>s'),
        # Index-only pages in the dashboard, so no per-record link.
        Entry.new(key: 'option_types', model_name: 'Spree::OptionType',
                  permission: 'read_products', serializer_name: 'Spree::Api::V3::Admin::OptionTypeSerializer'),
        Entry.new(key: 'transfers', model_name: 'Spree::StockTransfer',
                  permission: 'read_stock', serializer_name: 'Spree::Api::V3::Admin::StockTransferSerializer'),

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

        # Marketing
        Entry.new(key: 'promotions', model_name: 'Spree::Promotion',
                  permission: 'read_promotions', serializer_name: 'Spree::Api::V3::Admin::PromotionSerializer',
                  dashboard_path: '/promotions/%<id>s'),
        Entry.new(key: 'gift_cards', model_name: 'Spree::GiftCard',
                  permission: 'read_gift_cards', serializer_name: 'Spree::Api::V3::Admin::GiftCardSerializer')
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
