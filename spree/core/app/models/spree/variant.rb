module Spree
  class Variant < Spree.base_class
    has_prefix_id :variant

    acts_as_paranoid
    acts_as_list scope: :product

    include Spree::MemoizedData
    include Spree::HasCustomFields
    include Spree::Metadata
    include Spree::Searchable
    include Spree::StorePreferences

    publishes_lifecycle_events

    MEMOIZED_METHODS = %w(in_stock on_sale backorderable tax_category options_text compare_at_price)

    DIMENSION_UNITS = %w[mm cm in ft]
    WEIGHT_UNITS = %w[g kg lb oz]

    belongs_to :product, -> { with_deleted }, touch: true, class_name: 'Spree::Product', inverse_of: :variants
    belongs_to :tax_category, class_name: 'Spree::TaxCategory', optional: true

    delegate :name, :name=, :description, :slug, :available_on, :make_active_at, :product_type_id,
             :meta_description, :meta_keywords, :product_type, to: :product

    normalizes :sku, with: ->(value) { value&.to_s&.strip }
    normalizes :hs_code, with: ->(value) { value&.to_s&.gsub(/[^0-9]/, '') }
    normalizes :country_of_origin, with: ->(value) { value&.to_s&.strip&.upcase }

    # we need to have this callback before any dependent: :destroy associations
    # https://github.com/rails/rails/issues/3458
    before_destroy :ensure_not_in_complete_orders
    after_destroy :remove_line_items_from_incomplete_orders

    with_options inverse_of: :variant do
      has_many :fulfillment_items, class_name: 'Spree::FulfillmentItem'
      has_many :line_items
      has_many :stock_levels, class_name: 'Spree::StockLevel', dependent: :destroy, autosave: true
    end
    has_many :inventory_units, class_name: 'Spree::FulfillmentItem', inverse_of: :variant, deprecated: true

    has_many :orders, through: :line_items
    with_options through: :stock_levels do
      has_many :stock_locations
      has_many :stock_movements
      has_many :stock_reservations
    end

    has_many :option_value_variants, class_name: 'Spree::OptionValueVariant'
    has_many :option_values, through: :option_value_variants, dependent: :destroy, class_name: 'Spree::OptionValue'

    has_many :images, -> { order(:position) }, as: :viewable, dependent: :destroy, class_name: 'Spree::Asset'

    has_many :variant_media, class_name: 'Spree::VariantMedia', dependent: :destroy
    # Order through the asset's product-level position so a variant's gallery
    # follows whatever ordering the merchant set on the product. There's no
    # per-variant reordering — link/unlink only.
    has_many :associated_media,
             -> { order(Spree::Asset.arel_table[:position].asc) },
             through: :variant_media, source: :asset, class_name: 'Spree::Asset'

    belongs_to :primary_media, class_name: 'Spree::Asset', optional: true, foreign_key: :primary_media_id

    has_many :prices,
             class_name: 'Spree::Price',
             dependent: :destroy,
             inverse_of: :variant,
             autosave: true

    has_many :wished_items, dependent: :destroy

    has_many :digitals

    before_validation :set_cost_currency
    before_validation :apply_pending_options, if: :pending_options?

    validates :cost_price, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
    validates :sku, uniqueness: { conditions: -> { where(deleted_at: nil) }, case_sensitive: false, scope: spree_base_uniqueness_scope },
                    allow_blank: true, unless: :disable_sku_validation?

    validates :dimensions_unit, inclusion: { in: DIMENSION_UNITS }, allow_blank: true
    validates :weight_unit, inclusion: { in: WEIGHT_UNITS }, allow_blank: true

    validates :backorder_limit, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }

    # Customs classification. Optional everywhere — only an international
    # shipment or a duties provider needs it, and each raises its own error
    # when it does. Carriers reject an HS code outside 6..13 digits, so the
    # format is checked here rather than at the label counter.
    validates :hs_code, format: { with: /\A\d{6,13}\z/ }, allow_blank: true
    validates :country_of_origin, format: { with: /\A[A-Z]{2}\z/ }, allow_blank: true

    after_create :create_stock_levels
    after_commit :clear_line_items_cache, on: :update

    after_save :create_default_stock_level, unless: :track_inventory?
    after_update_commit :handle_track_inventory_change

    after_create :increment_product_variant_count
    after_destroy :decrement_product_variant_count

    scope :in_stock, -> { left_joins(:stock_levels).where("#{Spree::Variant.table_name}.track_inventory = ? OR (#{Spree::StockLevel.table_name}.count_on_hand - #{Spree::StockLevel.table_name}.allocated_count) > ?", false, 0) }
    scope :backorderable, -> { left_joins(:stock_levels).where(Spree::StockLevel.table_name => { backorderable: true }) }
    scope :in_stock_or_backorderable, -> { in_stock.or(backorderable) }

    scope :eligible, -> { all }

    scope :not_discontinued, lambda {
      where(
        arel_table[:discontinue_on].eq(nil).or(
          arel_table[:discontinue_on].gteq(Time.current.beginning_of_minute)
        )
      )
    }

    scope :not_deleted, -> { where("#{Spree::Variant.quoted_table_name}.deleted_at IS NULL") }

    scope :for_currency_and_available_price_amount, lambda { |currency = nil|
      currency ||= Spree::Store.default.default_currency
      joins(:prices).where("#{Spree::Price.table_name}.currency = ?", currency).where("#{Spree::Price.table_name}.amount IS NOT NULL").distinct
    }

    scope :active, lambda { |currency = nil|
      not_discontinued.not_deleted.
        for_currency_and_available_price_amount(currency)
    }

    scope :with_option_value, lambda { |option_name, option_value|
      option_type_ids = OptionType.where(name: option_name).ids
      return none if option_type_ids.empty?

      joins(:option_values).where(Spree::OptionValue.table_name => { name: option_value, option_type_id: option_type_ids })
    }

    scope :with_digital_assets, -> { joins(:digitals) }

    # Free-text variant search: SKU, parent product name, and any
    # option-value presentation (e.g. "Red", "XL"). The 3-char floor
    # keeps single-letter queries from triggering a full scan.
    def self.search(query)
      return none if query.blank? || query.length < 3

      conditions = [
        search_condition(self, :sku, query),
        search_condition(Spree::OptionValue, :presentation, query),
      ]

      if Spree.use_translations?
        translation_table = Product::Translation.arel_table.alias(Product.translation_table_alias)
        sanitized = sanitize_query_for_search(query)
        conditions << translation_table[:name].lower.matches("%#{sanitized}%", '\\')
      else
        conditions << search_condition(Spree::Product, :name, query)
      end

      relation = joins(:product).left_joins(:option_values)
      relation = relation.join_translation_table(Product) if Spree.use_translations?
      relation.where(conditions.reduce(:or)).distinct
    end

    # Backward compatibility alias — remove in Spree 6.0
    scope :multi_search, ->(*args) { search(*args) }

    # FIXME: cost price should be represented with DisplayMoney class
    LOCALIZED_NUMBERS = %w(cost_price weight depth width height)

    LOCALIZED_NUMBERS.each do |m|
      define_method("#{m}=") do |argument|
        self[m] = Spree::LocalizedNumber.parse(argument) if argument.present?
      end
    end

    accepts_nested_attributes_for(
      :stock_levels,
      reject_if: ->(attributes) { attributes['stock_location_id'].blank? || attributes['count_on_hand'].blank? },
      allow_destroy: false
    )

    accepts_nested_attributes_for(
      :prices,
      reject_if: ->(attributes) { attributes['currency'].blank? || attributes['amount'].blank? },
      allow_destroy: true
    )

    accepts_nested_attributes_for(
      :option_value_variants,
      reject_if: ->(attributes) { attributes['option_value_id'].blank? },
      allow_destroy: false
    )

    self.whitelisted_ransackable_associations = %w[option_values product tax_category prices]
    self.whitelisted_ransackable_attributes = %w[weight depth width height sku discontinue_on cost_price cost_currency track_inventory
                                                 deleted_at product_id hs_code country_of_origin]
    self.whitelisted_ransackable_scopes = %i(product_name_or_sku_cont search_by_product_name_or_sku search)

    def self.product_name_or_sku_cont(query)
      sanitized_query = ActiveRecord::Base.sanitize_sql_like(query.to_s.downcase.strip)
      query_pattern = "%#{sanitized_query}%"
      sku_condition = arel_table[:sku].lower.matches(query_pattern)

      if Spree.use_translations?
        translation_arel_table = Product::Translation.arel_table.alias(Product.translation_table_alias)[:name]
        product_name_condition = translation_arel_table.lower.matches(query_pattern)

        joins(:product).
          join_translation_table(Product).
          where(product_name_condition.or(sku_condition))
      else
        product_name_condition = Product.arel_table[:name].lower.matches(query_pattern)
        joins(:product).where(product_name_condition.or(sku_condition))
      end
    end

    def self.search_by_product_name_or_sku(query)
      product_name_or_sku_cont(query)
    end

    # Returns the human name of the variant.
    # @return [String] the human name of the variant
    def human_name
      @human_name ||= option_values.
                      joins(option_type: :product_option_types).
                      merge(product.product_option_types).
                      reorder('spree_product_option_types.position').
                      pluck(:presentation).join('/')
    end

    # Returns true if the variant is available.
    # @return [Boolean] true if the variant is available
    def available?
      !discontinued? && product.available?
    end

    # Returns true if the variant is sold as a pre-order: the product is active
    # and not deleted, the variant is flagged preorderable and not discontinued,
    # and the "ships by" date is open-ended or still in the future.
    # Pre-order relaxes only the publish-date embargo, not the rest of the
    # availability rules. Like backorder, a pre-order can make the variant
    # purchasable beyond on-hand stock; the oversell cap is +backorder_limit+
    # (empty ⇒ unlimited), and it adds the ship-by promise.
    # @return [Boolean] true if the variant is a pre-order
    def preorder?
      !discontinued? && preorderable? && product.active? && !product.deleted? &&
        (preorder_ships_at.nil? || preorder_ships_at > Time.current)
    end

    # Returns true if the variant is in stock or backorderable.
    # @return [Boolean] true if the variant is in stock or backorderable
    def in_stock_or_backorderable?
      self.class.in_stock_or_backorderable.exists?(id: id)
    end

    # Returns tax category for Variant
    # @return [Spree::TaxCategory]
    def tax_category
      @tax_category ||= if self[:tax_category_id].nil?
                          product.tax_category
                        else
                          Spree::TaxCategory.find_by(id: self[:tax_category_id]) || product.tax_category
                        end
    end

    # Returns tax category ID for Variant
    # @return [Integer]
    def tax_category_id
      @tax_category_id ||= if self[:tax_category_id].nil?
                             product.tax_category_id
                           else
                             self[:tax_category_id]
                           end
    end

    # Returns the options text of the variant.
    # @return [String] the options text of the variant
    def options_text
      @options_text ||= if option_values.loaded?
                          option_values.sort_by do |ov|
                            ov.option_type.position
                          end.map { |ov| "#{ov.option_type.presentation}: #{ov.presentation}" }.to_sentence(words_connector: ', ', two_words_connector: ', ')
                        else
                          option_values.includes(:option_type).joins(:option_type).order("#{Spree::OptionType.table_name}.position").map do |ov|
                            "#{ov.option_type.presentation}: #{ov.presentation}"
                          end.to_sentence(words_connector: ', ', two_words_connector: ', ')
                        end
    end

    # Returns the exchange name of the variant.
    # @return [String] the exchange name of the variant
    def exchange_name
      option_values.any? ? options_text : name
    end

    # Returns the descriptive name of the variant.
    # @return [String] the descriptive name of the variant
    def descriptive_name
      option_values.any? ? "#{name} - #{options_text}" : name
    end

    # Plain-language contents description for a customs declaration. Customs
    # authorities reject marketing names, so merchants set an explicit one;
    # the product name is the fallback that keeps a declaration valid.
    # @return [String, nil]
    def customs_description_for_declaration
      customs_description.presence || name
    end

    # Returns the variant's media gallery.
    # Prefers product-level media linked via variant_media (5.5+) — these reuse
    # a single blob across variants. Falls back to direct variant images for
    # legacy uploads.
    # @return [ActiveRecord::Relation]
    def gallery_media
      return associated_media if has_associated_media?

      images
    end

    # Returns true if the variant has media (linked product-level or direct images).
    # Uses loaded associations when available, otherwise falls back to counter cache.
    # @return [Boolean]
    def has_media?
      return true if has_associated_media?
      return images.any? if images.loaded?

      media_count.positive?
    end

    alias has_images? has_media?

    # @return [Boolean] true if any product-level media is linked to this variant
    def has_associated_media?
      return variant_media.any? if variant_media.loaded?

      variant_media.exists?
    end

    # Updates primary_media_id to the first media item by position.
    # Called when media is added, removed, or reordered.
    # Uses gallery_media so product-level assets linked via VariantMedia are
    # considered alongside legacy variant-pinned images.
    def update_thumbnail!
      first_media = gallery_media.first
      update_column(:primary_media_id, first_media&.id)
    end

    # Returns second Image for Variant (for hover effects).
    # @return [Spree::Image, nil]
    def secondary_image
      images.second
    end

    # Returns all images except the primary media, combining variant and product images.
    # @return [Array<Spree::Image>]
    def additional_images
      @additional_images ||= (images + product.images).uniq.reject { |image| image.id == primary_media&.id }
    end

    # Returns an array of hashes with the option type name, value and presentation
    # @return [Array<Hash>]
    def options
      @options ||= option_values.
                   includes(option_type: :product_option_types).
                   merge(product.product_option_types).
                   reorder('spree_product_option_types.position').
                   map do |option_value|
                     {
                       name: option_value.option_type.name,
                       value: option_value.name,
                       presentation: option_value.presentation
                     }
                   end
    end

    # Sets the option values for the variant
    # @param options [Array<Hash>] the options to set
    # @return [void]
    def options=(options = {})
      if product.nil?
        @pending_options = options
        return
      end

      options.each do |option|
        next if option[:name].blank? || option[:value].blank?

        set_option_value(option[:name], option[:value], option[:position])
      end
    end

    # Sets the option value for the given option name.
    # @param opt_name [String] the option name to set the option value for
    # @param opt_value [String] the option value to set
    # @param opt_type_position [Integer] the position of the option type
    # @return [void]
    def set_option_value(opt_name, opt_value, opt_type_position = nil)
      option_type = Spree::OptionType.where(name: opt_name.parameterize).first_or_initialize do |o|
        o.name = o.presentation = opt_name
        o.save!
      end

      current_value = find_option_value(opt_name)

      if current_value.nil?
        # then we have to check to make sure that the product has the option type
        product_option_type = if (existing_prod_ot = product.product_option_types.find { |ot| ot.option_type_id == option_type.id })
                                existing_prod_ot
                              else
                                product_option_type = product.product_option_types.new
                                product_option_type.option_type = option_type
                              end
        product_option_type.position = opt_type_position if opt_type_position
        product_option_type.save! if product_option_type.new_record? || product_option_type.changed?
      else
        return if current_value.name.parameterize == opt_value.parameterize

        option_values.delete(current_value)
      end

      option_value = option_type.option_values.where(name: opt_value.parameterize).first_or_initialize do |o|
        o.name = o.presentation = opt_value
        o.save!
      end

      option_values << option_value
      save
    end

    # Returns the option value for the given option name.
    # @param opt_name [String] the option name to get the option value for
    # @return [Spree::OptionValue] the option value for the given option name
    def find_option_value(opt_name)
      option_values.includes(:option_type).detect { |o| o.option_type.name.parameterize == opt_name.parameterize }
    end

    # Returns the presentation of the option value for the given option type.
    # @param option_type [Spree::OptionType] the option type to get the option value for
    # @return [String] the presentation of the option value for the given option type
    def option_value(option_type)
      if option_type.is_a?(Spree::OptionType)
        option_values.detect { |o| o.option_type_id == option_type.id }.try(:presentation)
      else
        find_option_value(option_type).try(:presentation)
      end
    end

    # Returns the base price (global price, not from a price list) for the given currency.
    # Use price_for(context) when you need to resolve prices including price lists.
    # @param currency [String] the currency to get the price for
    # @return [Spree::Price] the base price for the given currency
    def price_in(currency)
      currency = currency&.upcase

      price = if prices.loaded? && prices.any?
                prices.detect { |p| p.currency == currency && p.price_list_id.nil? }
              else
                prices.base_prices.find_by(currency: currency)
              end

      if price.nil?
        return Spree::Price.new(
          currency: currency,
          variant_id: id
        )
      end

      price
    rescue TypeError
      Spree::Price.new(
        currency: currency,
        variant_id: id
      )
    end

    # Returns the amount for the given currency.
    # @param currency [String] the currency to get the amount for
    # @return [BigDecimal] the amount for the given currency
    def amount_in(currency)
      price_in(currency).try(:amount)
    end

    # Returns the compare at amount for the given currency.
    # @param currency [String] the currency to get the compare at amount for
    # @return [BigDecimal] the compare at amount for the given currency
    def compare_at_amount_in(currency)
      price_in(currency).try(:compare_at_amount)
    end

    # Syncs base prices from an array of hashes.
    # Upserts prices for listed currencies, removes base prices for unlisted currencies.
    # On new records, builds prices in memory (saved when variant is saved).
    # On persisted records, saves prices immediately and removes unlisted currencies.
    # An empty array clears every base price — distinguished from `nil` (no
    # change requested), which falls through to the default ActiveRecord setter.
    # @param prices_params [Array<Hash>, nil] array of { currency:, amount:, compare_at_amount: }
    # @return [void]
    def prices=(prices_params)
      return super if prices_params.nil? || prices_params.first.is_a?(Spree::Price)

      currencies_in_payload = []

      prices_params.each do |price_data|
        price_data = price_data.to_h.with_indifferent_access
        currencies_in_payload << price_data[:currency]
        set_price(price_data[:currency], price_data[:amount], price_data[:compare_at_amount])
      end

      # Remove base prices for currencies not in the payload (including the
      # `prices_params == []` case, which clears every base price).
      prices.base_prices.where.not(currency: currencies_in_payload).destroy_all if persisted?
    end

    # Syncs stock items from an array of hashes.
    # Upserts stock for listed locations, soft-deletes stock items for unlisted locations.
    # On new records, defers to after_create callback.
    # @param stock_levels_params [Array<Hash>] array of { stock_location_id:, count_on_hand:, backorderable: }
    # @return [void]
    def stock_levels=(stock_levels_params)
      return super if stock_levels_params.blank? || stock_levels_params.first.is_a?(Spree::StockLevel)

      location_ids_in_payload = []

      stock_levels_params.each do |stock_data|
        stock_data = stock_data.to_h.with_indifferent_access
        location = Spree::StockLocation.find_by_param(stock_data[:stock_location_id])
        location_ids_in_payload << location.id
        set_stock(stock_data[:count_on_hand], stock_data[:backorderable], location)
      end

      # Soft-delete stock levels for locations not in the payload
      stock_levels.where.not(stock_location_id: location_ids_in_payload).destroy_all if persisted?
    end

    # @deprecated Use {#stock_levels}; removed in 6.1.
    def stock_items
      Spree::Deprecation.warn('Spree::Variant#stock_items is deprecated and will be removed in Spree 6.1. Use #stock_levels instead.')
      stock_levels
    end

    # @deprecated Use {#stock_levels=}; removed in 6.1.
    def stock_items=(value)
      Spree::Deprecation.warn('Spree::Variant#stock_items= is deprecated and will be removed in Spree 6.1. Use #stock_levels= instead.')
      self.stock_levels = value
    end

    # The v3 API sends `stock_levels: [...]`, which the params normalizer
    # rewrites to nested attributes — and Rails would then write count_on_hand
    # straight onto the row. Each entry is routed through {#set_stock} instead,
    # so a count typed in the dashboard lands in the stock history like every
    # other change. Entries are upserted and never removed, which is what
    # accepts_nested_attributes_for did here.
    #
    # @param rows [Array<Hash>, Hash]
    # @return [void]
    def stock_levels_attributes=(rows)
      rows = rows.values if rows.respond_to?(:values) && !rows.is_a?(Array)

      Array.wrap(rows).each do |row|
        row = (row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h : row.to_h).with_indifferent_access
        next if row[:stock_location_id].blank? || row[:count_on_hand].blank?

        stock_location = Spree::StockLocation.find_by_param(row[:stock_location_id])
        next if stock_location.nil?

        set_stock(row[:count_on_hand], row[:backorderable], stock_location)
      end
    end

    # @deprecated Use +stock_levels_attributes=+; removed in 6.1.
    def stock_items_attributes=(value)
      Spree::Deprecation.warn('Spree::Variant#stock_items_attributes= is deprecated and will be removed in Spree 6.1. Use #stock_levels_attributes= instead.')
      self.stock_levels_attributes = value
    end

    # Sets the base price (global price, not for a price list) for the given currency.
    # @param currency [String] the currency to set the price for
    # @param amount [BigDecimal] the amount to set
    # @param compare_at_amount [BigDecimal] the compare at amount to set
    # @return [void]
    def set_price(currency, amount, compare_at_amount = nil)
      # When the prices association is already loaded (eager-loaded for
      # serialization), reuse the cached base-price instance so readers that
      # branch on `prices.loaded?` (Pricing::Resolver, #price_in, serializers)
      # observe the write without a reload. `base_prices.find_or_initialize_by`
      # would issue a fresh query and return a detached object, leaving the
      # loaded collection — and the serialized response — stale.
      existing =
        if prices.loaded?
          prices.detect { |p| p.price_list_id.nil? && p.currency == currency }
        else
          prices.base_prices.find_by(currency: currency)
        end

      # A blank amount means the merchant left that currency empty, which is
      # the same statement as leaving it out of the payload: there is no base
      # price in this currency. Writing it would persist a nil amount, and a
      # base price (unlike a price-list placeholder) must have one.
      if amount.blank?
        return if existing.nil?

        prices.delete(existing) if prices.loaded?
        existing.destroy if existing.persisted?
        return
      end

      price = existing || if prices.loaded?
                            prices.build(currency: currency)
                          else
                            prices.base_prices.build(currency: currency)
                          end

      price.amount = amount
      price.compare_at_amount = compare_at_amount
      price.save! if persisted?
    end

    # Returns the price for the given context or options.
    # @param context_or_options [Spree::Pricing::Context|Hash] the context or options to get the price for
    # @return [Spree::Price] the price for the given context or options
    def price_for(context_or_options)
      context = if context_or_options.is_a?(Spree::Pricing::Context)
                  context_or_options
                elsif context_or_options.is_a?(Hash)
                  Spree::Pricing::Context.new(**context_or_options.merge(variant: self))
                else
                  raise ArgumentError, 'Must provide a Pricing::Context or options hash'
                end

      Spree::Pricing::Resolver.new(context).resolve
    end

    # Sets the count at a location. The correction goes through an `adjusted`
    # movement so it shows up in the stock history like every other change.
    # A count below zero is refused whatever the variant's backorder settings
    # say, so a caller passing one gets ActiveRecord::RecordInvalid.
    #
    # @param count_on_hand [Integer] the count the level should end up at
    # @param backorderable [Boolean, nil] left as it is when nil
    # @param stock_location [Spree::StockLocation, nil] defaults to the store's
    # @return [void]
    def set_stock(count_on_hand, backorderable = nil, stock_location = nil)
      stock_location ||= default_stock_location
      stock_level = stock_levels.find_or_initialize_by(stock_location: stock_location)
      # `unless nil?`, not `if present?` — a caller passing false means it.
      stock_level.backorderable = backorderable unless backorderable.nil?

      # Nothing is saved yet, so the count rides on the in-memory record and
      # the autosave association persists it with the variant.
      unless persisted?
        stock_level.count_on_hand = count_on_hand
        return
      end

      stock_level.save! if stock_level.changed?

      delta = count_on_hand.to_i - stock_level.count_on_hand.to_i
      return if delta.zero?

      stock_location.adjust(self, delta, reason: Spree::StockMovement.default_adjustment_reason)
    end

    def default_stock_location
      Spree::Store.current.default_stock_location
    end

    def price_modifier_amount_in(currency, options = {})
      return 0 unless options.present?

      options.keys.map do |key|
        m = "#{key}_price_modifier_amount_in".to_sym
        if respond_to? m
          send(m, currency, options[key])
        else
          0
        end
      end.sum
    end

    # Returns the price modifier amount of the variant.
    # @param options [Hash] the options to get the price modifier amount for
    # @return [BigDecimal] the price modifier amount of the variant
    def price_modifier_amount(options = {})
      return 0 unless options.present?

      options.keys.map do |key|
        m = "#{key}_price_modifier_amount".to_sym
        if respond_to? m
          send(m, options[key])
        else
          0
        end
      end.sum
    end

    # Returns the compare at price of the variant.
    # @return [BigDecimal] the compare at price of the variant
    def compare_at_price
      @compare_at_price ||= price_in(cost_currency).try(:compare_at_amount)
    end

    # Returns true if the variant is in stock.
    # @return [Boolean] true if the variant is in stock
    def in_stock?
      @in_stock ||= total_on_hand.positive?
    end

    # Returns true if the variant is backorderable.
    # @return [Boolean] true if the variant is backorderable
    def backorderable?
      @backorderable ||= quantifier.backorderable?
    end

    def on_sale?(currency)
      @on_sale ||= price_in(currency)&.discounted?
    end

    delegate :total_on_hand, :available_stock, :reserved_quantity, :can_supply?, to: :quantifier

    alias is_backorderable? backorderable?

    def purchasable?
      in_stock? || oversellable_now?
    end

    # Whether the variant can currently be bought by overselling — via
    # backorder or pre-order. Unlimited when +backorder_limit+ is nil (empty =
    # no cap); with a limit, purchasable only while the oversell allowance
    # remains.
    #
    # @return [Boolean]
    def oversellable_now?
      return false unless backorderable? || preorder?

      backorder_limit.nil? || can_supply?(1)
    end

    # Shortcut method to determine if inventory tracking is enabled for this variant
    # This considers both the variant tracking flag and the store's setting
    def should_track_inventory?
      track_inventory? && store_preference(:track_inventory_levels)
    end

    # Variants carry no store of their own; the product owns it.
    # @return [Spree::Store, nil]
    def preference_store
      product&.store
    end

    def volume
      (width || 0) * (height || 0) * (depth || 0)
    end

    def dimension
      (width || 0) + (height || 0) + (depth || 0)
    end

    # Returns the weight unit for the variant
    # @return [String]
    def weight_unit
      attributes['weight_unit'] || Spree::Store.default.preferred_weight_unit
    end

    def discontinue!
      update_attribute(:discontinue_on, Time.current)
    end

    def discontinued?
      !!discontinue_on && discontinue_on <= Time.current
    end

    def backordered?
      @backordered ||= !in_stock? && stock_levels.exists?(backorderable: true)
    end

    # Is this variant purely digital? (no physical product)
    #
    # @return [Boolean]
    def digital?
      product.digital?
    end

    def with_digital_assets?
      digitals.any?
    end

    private

    def pending_options?
      @pending_options.present?
    end

    def apply_pending_options
      return unless @pending_options

      options_to_apply = @pending_options
      @pending_options = nil

      options_to_apply.each do |option|
        next if option[:name].blank? || option[:value].blank?

        set_option_value(option[:name], option[:value], option[:position])
      end
    end

    def ensure_not_in_complete_orders
      if orders.complete.any?
        errors.add(:base, :cannot_destroy_if_attached_to_line_items)
        throw(:abort)
      end
    end

    def remove_line_items_from_incomplete_orders
      Spree::Variants::RemoveFromIncompleteOrdersJob.perform_later(self)
    end

    def quantifier
      Spree::Stock::Quantifier.new(self)
    end

    def set_cost_currency
      self.cost_currency = Spree::Store.default.default_currency if cost_currency.blank?
    end

    # Only the product's own store's locations — a new variant must not grow
    # stock items in every other store's warehouses.
    def create_stock_levels
      locations = product&.store ? product.store.stock_locations : StockLocation.all
      locations.where(propagate_all_variants: true).each do |stock_location|
        stock_location.propagate_variant(self)
      end
    end

    def disable_sku_validation?
      store_preference(:disable_sku_validation)
    end

    def clear_line_items_cache
      line_items.update_all(updated_at: Time.current)
    end

    def create_default_stock_level
      return if stock_levels.any?

      Spree::Store.current.default_stock_location.set_up_stock_level(self)
    end

    # Turning tracking off writes the remaining stock away. That is a stock
    # decision, so it goes in the log like any other correction rather than
    # disappearing through update_all.
    def handle_track_inventory_change
      return unless track_inventory_previously_changed?
      return if track_inventory

      stock_levels.reload.each do |stock_level|
        next if stock_level.count_on_hand.zero?

        stock_level.stock_location.adjust(
          self, -stock_level.count_on_hand, reason: Spree::StockMovement.default_adjustment_reason
        )
      end
    end

    def increment_product_variant_count
      Spree::Product.increment_counter(:variant_count, product_id)
    end

    def decrement_product_variant_count
      Spree::Product.decrement_counter(:variant_count, product_id)
    end
  end
end
