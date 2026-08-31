module Spree
  class Variant < Spree.base_class
    has_prefix_id :variant

    acts_as_paranoid
    acts_as_list scope: :product

    include Spree::MemoizedData
    include Spree::HasCustomFields
    include Spree::Metadata
    include Spree::HasExternalReferences
    include Spree::Searchable
    include Spree::StorePreferences

    publishes_lifecycle_events

    MEMOIZED_METHODS = %w(in_stock on_sale backorderable tax_category tax_category_id options_text compare_at_price)

    DIMENSION_UNITS = %w[mm cm in ft]
    WEIGHT_UNITS = %w[g kg lb oz]

    # What a buyer is quoted in. Stored quantities are units at every level;
    # this only changes the vocabulary a storefront presents.
    PURCHASE_UNITS = %w[unit carton]

    belongs_to :product, -> { with_deleted }, touch: true, class_name: 'Spree::Product', inverse_of: :variants
    belongs_to :tax_category, class_name: 'Spree::TaxCategory', optional: true
    # Which seller sells this variant. Nil is the operator's own listing, and
    # on a product whose seller owns every variant the product answers instead
    # — see #resolved_seller_id. Several sellers on one product is the whole point: two
    # of them are two variant rows, so their stock, prices and line-item
    # attribution are separate by construction.
    belongs_to :seller, class_name: 'Spree::Seller', optional: true
    # Nil defers to the product, exactly as tax_category does.
    belongs_to :delivery_profile, class_name: 'Spree::DeliveryProfile', optional: true

    delegate :name, :name=, :description, :slug, :available_on, :make_active_at, :product_type_id,
             :meta_description, :meta_keywords, :product_type, to: :product

    normalizes :sku, with: ->(value) { value&.to_s&.strip }
    normalizes :hs_code, with: ->(value) { value&.to_s&.gsub(/[^0-9]/, '') }
    normalizes :country_of_origin, with: ->(value) { value&.to_s&.strip&.upcase }

    # we need to have this callback before any dependent: :destroy associations
    # https://github.com/rails/rails/issues/3458
    before_destroy :ensure_not_in_complete_orders
    after_destroy :remove_line_items_from_incomplete_orders

    # Terms stated for this variant go with it. Nothing below the cart layer
    # reads them, but a row pointing at a destroyed variant would resolve for
    # nobody and count against the agreement's overrides forever.
    has_many :catalog_quantity_rules, class_name: 'Spree::CatalogQuantityRule',
                                      dependent: :destroy, inverse_of: :variant

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

    has_many :images, -> { order(:position) }, as: :viewable, dependent: :destroy, class_name: 'Spree::Media'

    has_many :variant_media, class_name: 'Spree::VariantMedia', dependent: :destroy
    # Order through the asset's product-level position so a variant's gallery
    # follows whatever ordering the merchant set on the product. There's no
    # per-variant reordering — link/unlink only.
    has_many :associated_media,
             -> { order(Spree::Media.arel_table[:position].asc) },
             through: :variant_media, source: :asset, class_name: 'Spree::Media'

    belongs_to :primary_media, class_name: 'Spree::Media', optional: true, foreign_key: :primary_media_id

    has_many :prices,
             class_name: 'Spree::Price',
             dependent: :destroy,
             inverse_of: :variant,
             autosave: true

    has_many :wished_items, dependent: :destroy

    has_many :digital_assets, class_name: 'Spree::DigitalAsset', dependent: :destroy
    has_many :digitals, class_name: 'Spree::DigitalAsset', deprecated: true

    before_validation :set_cost_currency
    before_validation :apply_pending_options, if: :pending_options?
    before_validation :apply_pending_stock_levels, if: :pending_stock_levels?

    validates :cost_price, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
    # Uniqueness is scoped to the seller — see #validate_sku_uniqueness. Written
    # by hand rather than as a `scope:` option because the seller is resolved
    # (the variant's own, else its product's) and the built-in validator reads
    # the raw column, which would let two sellers who each own a whole product
    # collide.
    validate :validate_sku_uniqueness, if: -> { sku.present? && !disable_sku_validation? }

    # Both guards catch raw prefixed-id assignment as well as association
    # writes, the way the same pair does on Product: a seller or a shipping
    # configuration from another store must never be reachable by id.
    validate :seller_must_belong_to_store, if: -> { will_save_change_to_seller_id? }
    validate :delivery_profile_must_belong_to_store, if: -> { will_save_change_to_delivery_profile_id? }

    # On an owned product the variant's own seller and profile columns carry
    # no meaning — every variant is the product's seller's and ships as the
    # product does — so they are kept blank rather than validated. A client
    # that reads a resolved `seller_id` and writes it straight back therefore
    # changes nothing, and the storefront never has to know which mode it is
    # in. Only a variant on a master product keeps what it is given.
    before_validation :blank_owned_product_overrides

    validates :dimensions_unit, inclusion: { in: DIMENSION_UNITS }, allow_blank: true
    validates :weight_unit, inclusion: { in: WEIGHT_UNITS }, allow_blank: true

    validates :backorder_limit, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }

    # Base purchasing rules. Blank means unrestricted, so the columns start
    # empty and every existing variant keeps buying one at a time.
    validates :minimum_order_quantity, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
    validates :order_multiple, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
    validates :units_per_carton, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
    validates :purchase_unit, inclusion: { in: PURCHASE_UNITS }, allow_blank: true

    # Both are data errors the merchant should hear about while editing, not
    # discover through a customer complaint: an order multiple that straddles
    # carton boundaries can never be shipped whole, and quoting cartons
    # without saying how many units one holds leaves the storefront no way to
    # render the offer.
    validate :order_multiple_fits_cartons
    validate :carton_purchase_unit_has_divisor

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

    # Variants whose *resolved* seller is the given one: their own column when
    # set, otherwise their product's. Passing nil selects first-party listings,
    # which on a store with no sellers is the whole catalog.
    scope :for_seller, lambda { |seller|
      seller_id = seller.respond_to?(:id) ? seller.id : seller
      own = arel_table[:seller_id]
      products = Spree::Product.arel_table[:seller_id]

      relation = joins(:product)
      if seller_id.nil?
        relation.where(own.eq(nil).and(products.eq(nil)))
      else
        relation.where(own.eq(seller_id).or(own.eq(nil).and(products.eq(seller_id))))
      end
    }

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

    scope :with_digital_assets, -> { joins(:digital_assets) }

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

    self.whitelisted_ransackable_associations = %w[option_values product tax_category prices seller]
    # `seller_id` and `delivery_profile_id` are deliberately absent: they are
    # the raw columns, nil on every variant that inherits from its product —
    # so "filter by seller" against them would silently miss the inheritors,
    # which on a single-owner catalog is all of them. Server-side callers
    # narrow by seller with the `for_seller` scope, which resolves the way
    # `resolved_seller` does; a client-facing filter needs an endpoint that
    # applies it, not an allowlist entry that quietly answers a different
    # question.
    self.whitelisted_ransackable_attributes = %w[weight depth width height sku discontinue_on cost_price cost_currency track_inventory
                                                 deleted_at product_id hs_code country_of_origin
                                                 minimum_order_quantity order_multiple purchase_unit units_per_carton]
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

    # Who sells this variant. Two modes, and they never mix:
    #
    # * An OWNED product (`product.seller_id` set) — every variant is that
    #   seller's, by definition. No other seller can create a variant here, so
    #   the variant's own column is meaningless and is kept blank.
    # * A MASTER product (`product.seller_id` nil) — the shared catalog. This
    #   is the only place `variant.seller_id` means anything: several sellers
    #   list variants on one page, and each row names its own.
    #
    # So the answer is the product's seller if it has one, else the variant's
    # own — a plain read, not an inheritance chain. Line items snapshot it at
    # add-to-cart, and the buy box and SKU check read it. Nil is first-party.
    #
    # @return [Spree::Seller, nil]
    def resolved_seller
      product&.seller || seller
    end

    # @return [Integer, nil]
    def resolved_seller_id
      product&.seller_id || self[:seller_id]
    end

    # Whether this variant sits on an owned product — the mode in which the
    # variant's own seller and delivery-profile columns carry no meaning.
    #
    # @return [Boolean]
    def owned_by_product_seller?
      product&.seller_id.present?
    end

    # How this variant ships, on the same two-mode rule as the seller, keyed
    # on OWNERSHIP rather than on whether the product has a profile — every
    # product does, so "product's profile if set" would never reach the
    # variant's own and no seller on a master could ship differently.
    #
    # * Owned product: every variant ships as the product does; the variant's
    #   own column is meaningless and is kept blank.
    # * Master product: each seller's row names how that seller ships, and
    #   falls back to the master's profile when it does not.
    #
    # A plain read, not memoized.
    #
    # @return [Spree::DeliveryProfile, nil]
    def resolved_delivery_profile
      return product&.resolved_delivery_profile if owned_by_product_seller?

      delivery_profile || product&.resolved_delivery_profile
    end

    # @return [Integer, nil]
    def resolved_delivery_profile_id
      resolved_delivery_profile&.id
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
      # Read through a fresh scope, never the cached association — this runs
      # from a media row's after_commit, and a loaded `images`/`associated_media`
      # would be missing the sibling rows created after it.
      candidates = gallery_media.reload.to_a
      # See Product#update_thumbnail! — a video without a still can't be a thumbnail.
      first_media = candidates.find(&:renderable_as_image?)

      update_column(:primary_media_id, first_media&.id)
    end

    # @deprecated Read #gallery_media directly; removed in 6.1. Nothing in
    #   Spree calls this — a hover image is a storefront presentation choice,
    #   not something core should name.
    # @return [Spree::Media, nil]
    def secondary_image
      Spree::Deprecation.warn('Spree::Variant#secondary_image is deprecated and will be removed in Spree 6.1. Use #gallery_media instead.')
      gallery_media.second
    end

    # @deprecated Read #gallery_media directly; removed in 6.1. Nothing in
    #   Spree calls this, and which images to show beside the main one is a
    #   storefront presentation choice.
    # @return [Array<Spree::Media>]
    def additional_images
      Spree::Deprecation.warn('Spree::Variant#additional_images is deprecated and will be removed in Spree 6.1. Use #gallery_media instead.')
      gallery_media.reject { |media| media.id == primary_media&.id }
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
      return if defer_stock_levels(:stock_levels=, stock_levels_params)

      location_ids_in_payload = []

      stock_levels_params.each do |stock_data|
        stock_data = stock_data.to_h.with_indifferent_access
        location = stock_location_for_param(stock_data[:stock_location_id])
        # A stale or foreign location id is skipped rather than raising, which
        # is what #stock_levels_attributes= already does for the same payload.
        next if location.nil?

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
      return if defer_stock_levels(:stock_levels_attributes=, rows)

      Array.wrap(rows).each do |row|
        row = (row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h : row.to_h).with_indifferent_access
        next if row[:stock_location_id].blank? || row[:count_on_hand].blank?

        stock_location = stock_location_for_param(row[:stock_location_id])
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
      # branch on `prices.loaded?` (the Internal provider's resolution,
      # #price_in, serializers)
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
    #
    # Answered by the store's pricing provider, which is Spree's own resolver
    # unless a connector has been configured. An external provider's price is
    # an unsaved, readonly Spree::Price — see Spree::PricingProvider::Base.
    #
    # @param context_or_options [Spree::Pricing::Context|Hash] the context or options to get the price for
    # @return [Spree::Price, nil] the price for the given context or options
    def price_for(context_or_options)
      context = if context_or_options.is_a?(Spree::Pricing::Context)
                  context_or_options
                elsif context_or_options.is_a?(Hash)
                  Spree::Pricing::Context.new(**context_or_options.merge(variant: self))
                else
                  raise ArgumentError, 'Must provide a Pricing::Context or options hash'
                end

      Spree::Pricing::PriceResolution.call(context)
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
    # Answered by the variant's own profile so a download and its printed
    # edition can sit on one product — the profile kind declares it, here as
    # everywhere else.
    #
    # @return [Boolean]
    def digital?
      !!resolved_delivery_profile&.digital?
    end

    def with_digital_assets?
      digital_assets.any?
    end

    # The variant's own purchasing rules — the base every cart obeys, and the
    # floor a buyer falls back to when their catalogs state nothing. A buyer's
    # effective rules resolve through {Spree::Catalogs::ResolveQuantityRules};
    # nothing below the cart layer reads either.
    #
    # @return [Spree::QuantityRule]
    def quantity_rule
      Spree::QuantityRule.new(
        minimum_order_quantity: minimum_order_quantity,
        order_multiple: order_multiple
      )
    end

    # True when this variant is quoted in cartons rather than units. Requires
    # +units_per_carton+, which the validation above guarantees.
    #
    # @return [Boolean]
    def sold_by_carton?
      purchase_unit == 'carton' && units_per_carton.to_i.positive?
    end

    # How many cartons a unit quantity fills, rounded up — a part carton still
    # ships as a carton. Nil when the variant declares no carton size.
    #
    # @param quantity [Integer]
    # @return [Integer, nil]
    def cartons_for(quantity)
      return nil unless units_per_carton.to_i.positive?

      (quantity.to_i / units_per_carton.to_f).ceil
    end

    private

    def order_multiple_fits_cartons
      return if order_multiple.to_i.zero? || units_per_carton.to_i.zero?
      return if (order_multiple % units_per_carton).zero? || (units_per_carton % order_multiple).zero?

      errors.add(:order_multiple, :incompatible_with_carton, units_per_carton: units_per_carton)
    end

    def carton_purchase_unit_has_divisor
      return unless purchase_unit == 'carton'
      return if units_per_carton.to_i.positive?

      errors.add(:units_per_carton, :required_for_carton_purchase_unit)
    end

    # Resolved through the product's own store, because
    # +Spree::StockLocation.find_by_param+ is global: an id belonging to another
    # store would otherwise resolve and put this variant's stock in that store's
    # warehouse. There is no global fallback — a variant is only reachable
    # through a product, and a product belongs to a store.
    #
    # @param param [String, Integer, nil] prefixed or raw stock location id
    # @return [Spree::StockLocation, nil]
    def stock_location_for_param(param)
      return if param.blank?

      product&.store&.stock_locations&.find_by_param(param)
    end

    # +product.variants.create(stock_levels_attributes: …)+ assigns attributes
    # before Rails wires the owner, so the store these location ids have to be
    # scoped against is not known yet. The payload waits for the product rather
    # than resolving against every warehouse in the installation.
    #
    # @return [Boolean] true when the write was deferred
    def defer_stock_levels(writer, payload)
      return false if product.present?

      @pending_stock_levels = { writer: writer, payload: payload }
      true
    end

    def pending_stock_levels?
      @pending_stock_levels.present?
    end

    def apply_pending_stock_levels
      pending = @pending_stock_levels
      @pending_stock_levels = nil

      public_send(pending[:writer], pending[:payload])
    end

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

    # A SKU identifies an item within one seller's catalog, not across the
    # marketplace: two sellers listing the same manufacturer part number is
    # ordinary, and rejecting the second one would be refusing the sale.
    #
    # Compared on the *resolved* seller, so a seller who owns whole products
    # is separated from another who does, not merged into the nil scope.
    #
    # Case-insensitive over a join, so it runs behind index_spree_variants_on_sku
    # rather than on it. A functional index on LOWER(sku) would suit it better,
    # but MariaDB rejects MySQL's syntax for one, so bulk writers that care pay
    # this or turn the check off with the disable_sku_validation preference.
    # Reads the raw column, not the resolved seller: what is being checked is
    # the variant's *own* link, and a product-owned variant has none to check.
    def blank_owned_product_overrides
      return unless owned_by_product_seller?

      self.seller_id = nil
      self.delivery_profile_id = nil
    end

    def seller_must_belong_to_store
      return if self[:seller_id].nil?

      store = product&.store
      return if store.nil?
      return if association(:seller).reader&.store_id == store.id

      errors.add(:seller, :invalid)
    end

    def delivery_profile_must_belong_to_store
      return if self[:delivery_profile_id].nil?

      store = product&.store
      return if store.nil?
      return if association(:delivery_profile).reader&.store_id == store.id

      errors.add(:delivery_profile, :invalid)
    end

    def validate_sku_uniqueness
      scope = self.class.for_seller(resolved_seller_id).
              where(deleted_at: nil).
              where(self.class.arel_table[:sku].lower.eq(sku.to_s.downcase))
      # Honour a host app's tenancy scope, as the validator this replaced did.
      # Empty in core, so this narrows nothing here.
      Array(self.class.spree_base_uniqueness_scope).each do |attribute|
        scope = scope.where(attribute => self[attribute])
      end
      scope = scope.where.not(id: id) if persisted?

      errors.add(:sku, :taken, value: sku) if scope.exists?
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
