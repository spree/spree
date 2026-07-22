module Spree
  module Reporting
    # Core's starter metric/dimension vocabulary. Installed by the engine
    # initializer before app initializers run, so applications and extensions
    # can register their own members (or `replace:` these) in
    # config/initializers.
    #
    # Model classes appear only inside lambdas and %{table} placeholders —
    # nothing here may autoload during initialization.
    module DefaultVocabulary
      def self.install(registry)
        registry.instance_eval do
          metric :gross_revenue, sql: 'SUM(%{orders}.total)', base: :orders, format: :money
          metric :net_revenue, sql: 'SUM(%{line_items}.pre_tax_amount)', base: :line_items, format: :money
          metric :orders_count, sql: 'COUNT(*)', base: :orders, format: :integer
          metric :units_sold, sql: 'SUM(%{line_items}.quantity)', base: :line_items, format: :integer
          metric :customers_count, sql: 'COUNT(DISTINCT %{orders}.email)', base: :orders, format: :integer
          metric :aov, ratio: %i[gross_revenue orders_count], format: :money

          dimension :completed_at, base: :orders, column: :completed_at, type: :time, grains: %i[day month]
          dimension :payment_status, base: :orders, column: :payment_state
          dimension :fulfillment_status, base: :orders, column: :shipment_state

          dimension :channel, base: :orders, column: :channel_id, lookup: :channel,
                    resolve: ->(store, value) { store.channels.find_by_prefix_id!(value).id },
                    hydrate: lambda { |store, ids, _params|
                      store.channels.where(id: ids).to_h do |channel|
                        [channel.id, { id: channel.prefixed_id, label: channel.name, meta: { code: channel.code } }]
                      end
                    }

          # Keys are order emails, so guests rank too; the id/profile link is
          # only present when a registered customer matches.
          dimension :customer, base: :orders, column: :email, lookup: :customer,
                    subject: -> { Spree.user_class }, key_scope: 'read_customers',
                    hydrate: lambda { |store, emails, _params|
                      users = store.customers.distinct.where(email: emails).index_by(&:email)
                      emails.to_h do |email|
                        user = users[email]
                        [email, { id: user&.prefixed_id, label: user&.full_name.presence || email, meta: { email: email } }]
                      end
                    }

          dimension :category, base: :line_items, column: '%{classifications}.taxon_id',
                    joins: [{ variant: { product: :classifications } }], lookup: :category,
                    subject: -> { Spree::Taxon }, key_scope: 'read_categories',
                    resolve: ->(store, value) { store.categories.find_by_prefix_id!(value).id },
                    hydrate: lambda { |store, ids, _params|
                      store.categories.where(id: ids).to_h do |category|
                        [category.id, { id: category.prefixed_id, label: category.name, meta: {} }]
                      end
                    }

          # Meta rides on the admin product serializer so thumbnails match the
          # rest of the Admin API; the lambda only runs inside API requests.
          dimension :product, base: :line_items, column: '%{variants}.product_id', joins: [:variant],
                    lookup: :product,
                    subject: -> { Spree::Product }, key_scope: 'read_products',
                    resolve: ->(store, value) { store.products.with_deleted.find_by_prefix_id!(value).id },
                    hydrate: lambda { |store, ids, params|
                      serializer = Spree.api.admin_product_serializer
                      store.products.with_deleted.includes(:primary_media).where(id: ids).to_h do |product|
                        serialized = serializer.new(product, params: params).to_h
                        [product.id, {
                          id: serialized['id'],
                          label: serialized['name'],
                          meta: {
                            slug: serialized['slug'],
                            thumbnail_url: serialized['thumbnail_url'],
                            price: serialized.dig('price', 'display_amount')
                          }
                        }]
                      end
                    }
        end
      end
    end
  end
end
