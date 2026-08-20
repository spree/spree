module Spree
  module Assistant
    # What the generic read tools are allowed to look at.
    #
    # An allowlist rather than "any model": the assistant reaches store data
    # through the same relations the Admin API uses, and a model that is not
    # listed here simply does not exist as far as the assistant is concerned.
    # Each entry names the association to scope through, so every lookup starts
    # from the current store rather than a bare model class.
    class ResourceMap
      Entry = Struct.new(:key, :model_name, :store_association, :permission, :serializer_name,
                         :dashboard_path, keyword_init: true) do
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

        # Records of this kind belonging to the given store.
        #
        # @param store [Spree::Store]
        # @return [ActiveRecord::Relation]
        def scope_for(store)
          store.public_send(store_association)
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
      end

      ENTRIES = [
        Entry.new(key: 'products', model_name: 'Spree::Product', store_association: :products,
                  permission: 'read_products', serializer_name: 'Spree::Api::V3::Admin::ProductSerializer',
                  dashboard_path: '/products/%<id>s'),
        Entry.new(key: 'orders', model_name: 'Spree::Order', store_association: :orders,
                  permission: 'read_orders', serializer_name: 'Spree::Api::V3::Admin::OrderSerializer',
                  dashboard_path: '/orders/%<id>s'),
        # Customers are deliberately absent: they are global rather than
        # store-owned, so there is no store association to scope through, and
        # inventing one for a surface that returns personal data is not a phase 1
        # decision. They arrive with a reviewed scoping path of their own.
        Entry.new(key: 'promotions', model_name: 'Spree::Promotion', store_association: :promotions,
                  permission: 'read_promotions', serializer_name: 'Spree::Api::V3::Admin::PromotionSerializer',
                  dashboard_path: '/promotions/%<id>s'),
        Entry.new(key: 'categories', model_name: 'Spree::Category', store_association: :categories,
                  permission: 'read_products', serializer_name: 'Spree::Api::V3::Admin::CategorySerializer',
                  dashboard_path: '/products/categories/%<id>s')
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
