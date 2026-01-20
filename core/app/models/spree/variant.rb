module Spree
  class Variant < Spree.base_class
    acts_as_paranoid
    acts_as_list scope: :product

    include Spree::MemoizedData
    include Spree::Metafields
    include Spree::Metadata
    include Spree::Variant::Webhooks

    publishes_lifecycle_events

    MEMOIZED_METHODS = %w(purchasable in_stock on_sale backorderable tax_category options_text compare_at_price)

    DIMENSION_UNITS = %w[mm cm in ft]
    WEIGHT_UNITS = %w[g kg lb oz]

    belongs_to :product, -> { with_deleted }, touch: true, class_name: 'Spree::Product', inverse_of: :variants
    belongs_to :tax_category, class_name: 'Spree::TaxCategory', optional: true

    delegate :name, :name=, :description, :slug, :available_on, :make_active_at, :shipping_category_id,
             :meta_description, :meta_keywords, :shipping_category, to: :product

    normalizes :sku, with: ->(value) { value&.to_s&.strip }

    # we need to have this callback before any dependent: :destroy associations
    # https://github.com/rails/rails/issues/3458
    before_destroy :ensure_not_in_complete_orders
    after_destroy :remove_line_items_from_incomplete_orders

    # must include this after ensure_not_in_complete_orders to make sure price won't be deleted before validation
    include Spree::DefaultPrice

    with_options inverse_of: :variant do
      has_many :inventory_units
      has_many :line_items
      has_many :stock_items, dependent: :destroy
    end

    has_many :orders, through: :line_items
    with_options through: :stock_items do
      has_many :stock_locations
      has_many :stock_movements
    end

    has_many :option_value_variants, class_name: 'Spree::OptionValueVariant'
    has_many :option_values, through: :option_value_variants, dependent: :destroy, class_name: 'Spree::OptionValue'

    has_many :images, -> { order(:position) }, as: :viewable, dependent: :destroy, class_name: 'Spree::Image'
    has_one :primary_image, -> { order(:position).limit(1) }, as: :viewable, class_name: 'Spree::Image'
    has_one :secondary_image, -> { order(:position).limit(1).offset(1) }, as: :viewable, class_name: 'Spree::Image'

    has_many :prices,
             class_name: 'Spree::Price',
             dependent: :destroy,
             inverse_of: :variant

    has_many :wished_items, dependent: :destroy

    has_many :digitals

    before_validation :set_cost_currency

    validate :check_price

    validates :option_value_variants, presence: true, unless: :is_master?

    with_options numericality: { greater_than_or_equal_to: 0, allow_nil: true } do
      validates :cost_price
      validates :price
    end
    validates :sku, uniqueness: { conditions: -> { where(deleted_at: nil) }, case_sensitive: false, scope: spree_base_uniqueness_scope },
                    allow_blank: true, unless: :disable_sku_validation?

    validates :dimensions_unit, inclusion: { in: DIMENSION_UNITS }, allow_blank: true
    validates :weight_unit, inclusion: { in: WEIGHT_UNITS }, allow_blank: true

    after_create :create_stock_items
    after_create :set_master_out_of_stock, unless: :is_master?
    after_commit :clear_line_items_cache, on: :update

    after_save :create_default_stock_item, unless: :track_inventory?
    after_update_commit :handle_track_inventory_change

    after_commit :remove_prices_from_master_variant, on: [:create, :update], unless: :is_master?
    after_commit :remove_stock_items_from_master_variant, on: :create, unless: :is_master?
    after_create :increment_product_variant_count, unless: :is_master?
    after_destroy :decrement_product_variant_count, unless: :is_master?

    after_touch :clear_in_stock_cache

    scope :in_stock, -> { left_joins(:stock_items).where("#{Spree::Variant.table_name}.track_inventory = ? OR #{Spree::StockItem.table_name}.count_on_hand > ?", false, 0) }
    scope :backorderable, -> { left_joins(:stock_items).where(spree_stock_items: { backorderable: true }) }
    scope :in_stock_or_backorderable, -> { in_stock.or(backorderable) }

    scope :eligible, -> {
      where(is_master: false).or(
        where(
          product_id: Spree::Variant.
                      select(:product_id).
                      group(:product_id).
                      having("COUNT(#{Spree::Variant.table_name}.id) = 1")
        )
      )
    }

    scope :not_discontinued, -> do
      where(
        arel_table[:discontinue_on].eq(nil).or(
          arel_table[:discontinue_on].gteq(Time.current)
        )
      )
    end

    scope :not_deleted, -> { where("#{Spree::Variant.quoted_table_name}.deleted_at IS NULL") }

    scope :for_currency_and_available_price_amount, ->(currency = nil) do
      currency ||= Spree::Store.default.default_currency
      joins(:prices).where("#{Spree::Price.table_name}.currency = ?", currency).where("#{Spree::Price.table_name}.amount IS NOT NULL").distinct
    end

    scope :active, ->(currency = nil) do
      not_discontinued.not_deleted.
        for_currency_and_available_price_amount(currency)
    end

    scope :with_option_value, lambda { |option_name, option_value|
      option_type_ids = OptionType.where(name: option_name).ids
      return none if option_type_ids.empty?

      joins(:option_values).where(Spree::OptionValue.table_name => { name: option_value, option_type_id: option_type_ids })
    }

    scope :with_digital_assets, -> { joins(:digitals) }

    if defined?(PgSearch)
      include PgSearch::Model

      pg_search_scope :search_by_sku, against: :sku, using: { tsearch: { prefix: true } }

      pg_search_scope :search_by_sku_or_options,
                      against: :sku,
                      using: { tsearch: { prefix: true } },
                      associated_against: { option_values: %i[presentation] }

      pg_search_scope :search_by_name_sku_or_options, against: :sku, associated_against: {
        product: %i[name],
        option_values: %i[presentation]
      }, using: { tsearch: { prefix: true } }

      scope :multi_search, lambda { |query|
        return none if query.blank? || query.length < 3

        search_by_name_sku_or_options(query)
      }
    else
      scope :multi_search, lambda { |query|
        return none if query.blank? || query.length < 3

        product_name_or_sku_cont(query)
      }
    end

    # FIXME: cost price should be represented with DisplayMoney class
    LOCALIZED_NUMBERS = %w(cost_price weight depth width height)

    LOCALIZED_NUMBERS.each do |m|
      define_method("#{m}=") do |argument|
        self[m] = Spree::LocalizedNumber.parse(argument) if argument.present?
      end
    end

    accepts_nested_attributes_for(
      :stock_items,
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

    self.whitelisted_ransackable_associations = %w[option_values product tax_category prices default_price]
    self.whitelisted_ransackable_attributes = %w[weight depth width height sku discontinue_on is_master cost_price cost_currency track_inventory deleted_at]
    self.whitelisted_ransackable_scopes = %i(product_name_or_sku_cont search_by_product_name_or_sku)

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
                          option_values.sort_by { |ov| ov.option_type.position }.map { |ov| "#{ov.option_type.presentation}: #{ov.presentation}" }.to_sentence(words_connector: ', ', two_words_connector: ', ')
                        else
                          option_values.includes(:option_type).joins(:option_type).order("#{Spree::OptionType.table_name}.position").map { |ov| "#{ov.option_type.presentation}: #{ov.presentation}" }.to_sentence(words_connector: ', ', two_words_connector: ', ')
                        end
    end

    # Returns the exchange name of the variant.
    # @return [String] the exchange name of the variant
    def exchange_name
      is_master? ? name : options_text
    end

    # Returns the descriptive name of the variant.
    # @return [String] the descriptive name of the variant
    def descriptive_name
      is_master? ? name + ' - Master' : name + ' - ' + options_text
    end

    # use deleted? rather than checking the attribute directly. this
    # allows extensions to override deleted? if they want to provide
    # their own definition.
    # @return [Boolean] true if the variant is deleted.
    def deleted?
      !!deleted_at
    end

    # Returns true if the variant has images.
    # @return [Boolean] true if the variant has images.
    def has_images?
      return images.any? if images.loaded?

      image_count.positive?
    end

    # Returns default Image for Variant
    # @return [Spree::Image]
    def default_image
      @default_image ||= if has_images?
                           images.loaded? ? images.first : primary_image
                         else
                           product.default_image
                         end
    end

    # Returns additional Images for Variant
    # @return [Array<Spree::Image>]
    def additional_images
      @additional_images ||= (images + product.images).uniq.find_all { |image| image.id != default_image&.id }
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
      # no option values on master
      return if is_master

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

    # Sets the base price (global price, not for a price list) for the given currency.
    # @param currency [String] the currency to set the price for
    # @param amount [BigDecimal] the amount to set
    # @param compare_at_amount [BigDecimal] the compare at amount to set
    # @return [void]
    def set_price(currency, amount, compare_at_amount = nil)
      price = prices.base_prices.find_or_initialize_by(currency: currency)
      price.amount = amount
      price.compare_at_amount = compare_at_amount if compare_at_amount.present?
      price.save!
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

    # Sets the stock for the variant
    # @param count_on_hand [Integer] the count on hand
    # @param backorderable [Boolean] the backorderable flag
    # @param stock_location [Spree::StockLocation] the stock location to set the stock for
    # @return [void]
    def set_stock(count_on_hand, backorderable = nil, stock_location = nil)
      stock_location ||= Spree::Store.current.default_stock_location
      stock_item = stock_items.find_or_initialize_by(stock_location: stock_location)
      stock_item.count_on_hand = count_on_hand
      stock_item.backorderable = backorderable if backorderable.present?
      stock_item.save!
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

    # Returns the name and sku of the variant.
    # @return [String] the name and sku of the variant
    def name_and_sku
      "#{name} - #{sku}"
    end

    # Returns the sku and options text of the variant.
    # @return [String] the sku and options text of the variant
    def sku_and_options_text
      "#{sku} #{options_text}".strip
    end

    # Returns true if the variant is in stock.
    # @return [Boolean] true if the variant is in stock
    def in_stock?
      @in_stock ||= if association(:stock_items).loaded? && association(:stock_locations).loaded?
                      total_on_hand.positive?
                    else
                      Rails.cache.fetch(in_stock_cache_key, version: cache_version) do
                        total_on_hand.positive?
                      end
                    end
    end

    # Returns true if the variant is backorderable.
    # @return [Boolean] true if the variant is backorderable
    def backorderable?
      @backorderable ||= Rails.cache.fetch(['variant-backorderable', cache_key_with_version]) do
        quantifier.backorderable?
      end
    end

    def on_sale?(currency)
      @on_sale ||= price_in(currency)&.discounted?
    end

    delegate :total_on_hand, :can_supply?, to: :quantifier

    alias is_backorderable? backorderable?

    def purchasable?
      @purchasable ||= in_stock? || backorderable?
    end

    # Shortcut method to determine if inventory tracking is enabled for this variant
    # This considers both variant tracking flag and site-wide inventory tracking settings
    def should_track_inventory?
      track_inventory? && Spree::Config.track_inventory_levels
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
      @backordered ||= !in_stock? && stock_items.exists?(backorderable: true)
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

    def clear_in_stock_cache
      Rails.cache.delete(in_stock_cache_key)
    end

    private

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

    def set_master_out_of_stock
      if product.master&.in_stock?
        product.master.stock_items.update_all(backorderable: false)
        product.master.stock_items.each(&:reduce_count_on_hand_to_zero)
      end
    end

    # Ensures a new variant takes the product master price when price is not supplied
    def check_price
      return if (has_default_price? && default_price.valid?) || prices.any?

      infer_price_from_default_variant_if_needed
      self.currency = Spree::Store.default.default_currency if price.present? && currency.nil?
    end

    def infer_price_from_default_variant_if_needed
      if price.nil?
        return errors.add(:base, :no_master_variant_found_to_infer_price) unless product&.master

        # At this point, master can have or have no price, so let's use price from the default variant
        self.price = product.default_variant.price
      end
    end

    def set_cost_currency
      self.cost_currency = Spree::Store.default.default_currency if cost_currency.blank?
    end

    def create_stock_items
      StockLocation.where(propagate_all_variants: true).each do |stock_location|
        stock_location.propagate_variant(self)
      end
    end

    def in_stock_cache_key
      "variant-#{id}-in_stock"
    end

    def disable_sku_validation?
      Spree::Config[:disable_sku_validation]
    end

    def clear_line_items_cache
      line_items.update_all(updated_at: Time.current)
    end

    def create_default_stock_item
      return if stock_items.any?

      Spree::Store.current.default_stock_location.set_up_stock_item(self)
    end

    def handle_track_inventory_change
      return unless track_inventory_previously_changed?
      return if track_inventory

      stock_items.update_all(count_on_hand: 0, updated_at: Time.current)
    end

    def remove_prices_from_master_variant
      product.master.prices.delete_all if prices.exists?
    end

    def remove_stock_items_from_master_variant
      product.master.stock_items.delete_all
    end

    def increment_product_variant_count
      Spree::Product.increment_counter(:variant_count, product_id)
    end

    def decrement_product_variant_count
      Spree::Product.decrement_counter(:variant_count, product_id)
    end
  end
end
