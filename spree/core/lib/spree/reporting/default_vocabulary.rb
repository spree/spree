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
      # Order-level money that lives on another table. Correlated on the
      # order's own id so the aggregate stays one value per order — joining
      # would multiply the base row and inflate every other metric in the
      # same query.
      REFUNDS_SUBQUERY = <<~SQL.squish.freeze
        SUM(COALESCE((SELECT SUM(r.amount) FROM %{refunds} r WHERE r.order_id = %{orders}.id), 0))
      SQL

      # A refund is issued against the order, not a line, so it is apportioned
      # by the line's share of the order's pre-tax value. The denominator is
      # summed over the order's own lines rather than read from item_total:
      # item_total is priced before discounts, so on a discounted order the
      # shares would not add up to one and part of the refund would vanish.
      # The `* 1.0` forces real division: SQLite divides two integer-valued
      # decimals as integers, which silently rounds every share to zero.
      LINE_ITEM_REFUNDS_SUBQUERY = <<~SQL.squish.freeze
        SUM(
          COALESCE((SELECT SUM(r.amount) FROM %{refunds} r WHERE r.order_id = %{orders}.id), 0)
          * CASE
              WHEN COALESCE((SELECT SUM(sibling.pre_tax_amount) FROM %{line_items} sibling
                             WHERE sibling.order_id = %{orders}.id), 0) > 0
              THEN (%{line_items}.pre_tax_amount * 1.0)
                   / (SELECT SUM(sibling.pre_tax_amount) FROM %{line_items} sibling
                      WHERE sibling.order_id = %{orders}.id)
              ELSE 0
            END
        )
      SQL

      # An order is the customer's first when no earlier completed order shares
      # its email in the same store.
      CUSTOMER_TYPE_SQL = <<~SQL.squish.freeze
        CASE WHEN EXISTS (
          SELECT 1 FROM %{orders} prior
          WHERE prior.email = %{orders}.email
            AND prior.store_id = %{orders}.store_id
            AND prior.status <> 'canceled'
            AND prior.completed_at IS NOT NULL
            AND prior.completed_at < %{orders}.completed_at
        ) THEN 'returning' ELSE 'first_time' END
      SQL

      DUTIES_SUBQUERY = <<~SQL.squish.freeze
        SUM(COALESCE((SELECT SUM(f.amount) FROM %{fees} f
                      WHERE f.order_id = %{orders}.id AND f.kind = 'duty'), 0))
      SQL

      SELLER_COMMISSION_SUBQUERY = <<~SQL.squish.freeze
        SUM(COALESCE((SELECT SUM(c.total) FROM %{commission_lines} c
                      WHERE c.line_item_id = %{line_items}.id), 0))
      SQL

      def self.install(registry)
        registry.instance_eval do
          # ---- the sales chain ----
          #
          # gross_sales - discounts - returns = net_sales
          # net_sales + shipping + duties + fees + taxes = total_sales
          #
          # Line-item money is the finest grain we hold, so the first three
          # terms aggregate on :line_items and the order-level charges on
          # :orders. Money that lives on another table (refunds, commissions)
          # is summed through a correlated subquery: an order with three
          # refunds must stay one row.

          metric :gross_sales, sql: 'SUM(%{line_items}.price * %{line_items}.quantity)',
                               base: :line_items, format: :money
          metric :discounts, sql: 'SUM(%{line_items}.discount_total)', base: :line_items, format: :money
          metric :returns, sql: REFUNDS_SUBQUERY, base: :orders, format: :money
          # Net of returns as well as discounts, so this is the figure a
          # merchant recognises as "what we actually sold".
          metric :net_sales, sql: "SUM(%{line_items}.pre_tax_amount) - #{LINE_ITEM_REFUNDS_SUBQUERY}",
                             base: :line_items, format: :money
          metric :shipping, sql: 'SUM(%{orders}.delivery_total)', base: :orders, format: :money
          metric :duties, sql: DUTIES_SUBQUERY, base: :orders, format: :money
          # Every shopper-visible fee except duties, which the chain counts separately.
          metric :fees, sql: "SUM(COALESCE(%{orders}.fee_total, 0)) - #{DUTIES_SUBQUERY}",
                        base: :orders, format: :money
          metric :taxes, sql: 'SUM(%{orders}.additional_tax_total + %{orders}.included_tax_total)',
                         base: :orders, format: :money
          # The order grand total, net of what came back.
          metric :total_sales, sql: "SUM(%{orders}.total) - #{REFUNDS_SUBQUERY}",
                               base: :orders, format: :money

          # ---- volume ----

          metric :orders, sql: 'COUNT(*)', base: :orders, format: :integer
          metric :units_sold, sql: 'SUM(%{line_items}.quantity)', base: :line_items, format: :integer
          metric :customers, sql: 'COUNT(DISTINCT %{orders}.email)', base: :orders, format: :integer
          metric :average_order_value, ratio: %i[total_sales orders], format: :money

          # ---- margin ----
          #
          # cost_price is nullable, so an uncosted variant contributes zero and
          # margin over an incompletely-costed catalogue reads high. Guessing a
          # cost would be worse than reporting the gap.
          metric :cost_of_goods, sql: 'SUM(COALESCE(%{line_items}.cost_price, 0) * %{line_items}.quantity)',
                                 base: :line_items, format: :money
          metric :gross_profit,
                 sql: 'SUM(%{line_items}.pre_tax_amount) - SUM(COALESCE(%{line_items}.cost_price, 0) * %{line_items}.quantity)',
                 base: :line_items, format: :money
          metric :gross_margin, ratio: %i[gross_profit net_sales], format: :percent

          # ---- marketplace ----
          #
          # A commission is a platform-to-seller settlement, never part of what
          # the shopper paid. Summed from the lines rather than the order's
          # denormalized total so it can be broken down by seller — an order
          # with two sellers owes each of them their own share.
          metric :commission, sql: SELLER_COMMISSION_SUBQUERY, base: :line_items, format: :money,
                              subject: -> { Spree::CommissionLine }, key_scope: 'read_commissions'
          # What the sellers are owed on these sales: the goods they sold, less
          # the marketplace's cut and anything the buyer sent back.
          metric :seller_payout,
                 sql: "SUM(%{line_items}.pre_tax_amount) - #{LINE_ITEM_REFUNDS_SUBQUERY} - #{SELLER_COMMISSION_SUBQUERY}",
                 base: :line_items, format: :money,
                 subject: -> { Spree::SellerTransfer }, key_scope: 'read_payouts'

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

          # First-time or returning, decided per order against the buyer's own
          # history rather than a stored flag: an order is "returning" when the
          # same email completed an earlier one. Imported history and canceled
          # orders therefore stay correct without a backfill.
          dimension :customer_type, base: :orders, expression: CUSTOMER_TYPE_SQL,
                    values: -> { %w[first_time returning] }

          # The seller who sold the line. Marketplace stores group by this;
          # single-seller stores get one row, which is honest.
          dimension :seller, base: :line_items, column: :seller_id, lookup: :seller,
                    subject: -> { Spree::Seller }, key_scope: 'read_sellers',
                    resolve: ->(store, value) { store.sellers.find_by_prefix_id!(value).id },
                    hydrate: lambda { |store, ids, _params|
                      store.sellers.where(id: ids).to_h do |seller|
                        [seller.id, { id: seller.prefixed_id, label: seller.name, meta: { slug: seller.slug } }]
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
