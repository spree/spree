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
          metric :discounts_total, sql: 'SUM(%{orders}.discount_total)', base: :orders, format: :money
          metric :delivery_total, sql: 'SUM(%{orders}.delivery_total)', base: :orders, format: :money
          metric :tax_total, sql: 'SUM(%{orders}.additional_tax_total + %{orders}.included_tax_total)',
                             base: :orders, format: :money

          dimension :completed_at, base: :orders, column: :completed_at, type: :time, grains: %i[day week month]
          dimension :payment_status, base: :orders, column: :payment_status,
                    values: -> { Spree::Order::PAYMENT_STATUSES }
          # The rollup values Orders::UpdateStatuses writes today; the model
          # constant still carries the legacy machine states until 6.1.
          dimension :fulfillment_status, base: :orders, column: :fulfillment_status,
                    values: -> { %w[backorder canceled partial unfulfilled fulfilled delivered] }

          # Keyed by ISO code straight off the shipping address — countries are
          # reference data (Spree::Country is not a record), so the code is the id.
          dimension :country, base: :orders, column: '%{addresses}.country_code', joins: [:ship_address],
                    lookup: :country,
                    hydrate: lambda { |_store, codes, _params|
                      codes.to_h do |code|
                        [code, { id: code, label: Spree::Country.by_iso(code)&.name || code, meta: {} }]
                      end
                    }

          dimension :market, base: :orders, column: :market_id, lookup: :market,
                    resolve: ->(store, value) { store.markets.find_by_prefix_id!(value).id },
                    hydrate: lambda { |store, ids, _params|
                      store.markets.where(id: ids).to_h do |market|
                        [market.id, { id: market.prefixed_id, label: market.name, meta: {} }]
                      end
                    }

          dimension :channel, base: :orders, column: :channel_id, lookup: :channel,
                    resolve: ->(store, value) { store.channels.find_by_prefix_id!(value).id },
                    hydrate: lambda { |store, ids, _params|
                      store.channels.where(id: ids).to_h do |channel|
                        [channel.id, { id: channel.prefixed_id, label: channel.name, meta: { code: channel.code } }]
                      end
                    }

          # Keyed by the order's email (guests have no customer row); a
          # prefixed customer id in a filter resolves to that customer's email.
          dimension :customer, base: :orders, column: :email, lookup: :customer,
                    subject: -> { Spree.customer_class }, key_scope: 'read_customers',
                    resolve: lambda { |store, value|
                      Spree::PrefixedId.prefixed_id?(value.to_s) ? Spree.customer_class.find_by_prefix_id!(value).email : value
                    },
                    hydrate: lambda { |store, emails, _params|
                      customers = store.customers.distinct.where(email: emails).index_by(&:email)
                      emails.to_h do |email|
                        customer = customers[email]
                        [email, { id: customer&.prefixed_id, label: customer&.full_name.presence || email, meta: { email: email } }]
                      end
                    }

          dimension :category, base: :line_items, column: '%{product_categories}.category_id',
                    joins: [{ variant: { product: :product_categories } }], lookup: :category,
                    subject: -> { Spree::Category }, key_scope: 'read_categories',
                    resolve: ->(store, value) { store.categories.find_by_prefix_id!(value).id },
                    hydrate: lambda { |store, ids, _params|
                      store.categories.where(id: ids).to_h do |category|
                        [category.id, { id: category.prefixed_id, label: category.name, meta: {} }]
                      end
                    }

          # SKU-level merchandising; the label carries the option values so
          # variants of one product stay distinguishable in a ranking.
          dimension :variant, base: :line_items, column: :variant_id, lookup: :variant,
                    subject: -> { Spree::Product }, key_scope: 'read_products',
                    resolve: ->(store, value) { store.variants.find_by_prefix_id!(value).id },
                    hydrate: lambda { |store, ids, _params|
                      store.variants.where(id: ids).includes(:product, option_values: :option_type).to_h do |variant|
                        [variant.id, {
                          id: variant.prefixed_id,
                          label: variant.descriptive_name,
                          meta: { sku: variant.sku, product_id: variant.product&.prefixed_id }
                        }]
                      end
                    }

          # Meta rides on the admin product serializer so thumbnails match the
          # rest of the Admin API; the lambda only runs inside API requests.
          dimension :product, base: :line_items, column: '%{variants}.product_id', joins: [:variant],
                    lookup: :product,
                    subject: -> { Spree::Product }, key_scope: 'read_products',
                    resolve: ->(store, value) { store.products.with_deleted.find_by_prefix_id!(value).id },
                    # Four display fields, read directly: the product serializer
                    # would resolve buy-box variants, price lists, seller, type
                    # and tax category per row and throw all of it away.
                    hydrate: lambda { |store, ids, _params|
                      currency = Spree::Current.currency || store.default_currency
                      products = store.products.with_deleted.includes(:primary_media).where(id: ids)
                      products.to_h do |product|
                        amount = product.default_variant&.amount_in(currency)
                        [product.id, {
                          id: product.prefixed_id,
                          label: product.name,
                          meta: {
                            slug: product.slug,
                            thumbnail_url: Spree::Reporting.image_url(product.primary_media),
                            price: (Spree::Money.new(amount, currency: currency).to_s if amount)
                          }
                        }]
                      end
                    }
        end
      end
    end
  end
end
