module Spree
  class Variant < Spree::Base
    acts_as_paranoid
    acts_as_list scope: :product

    include Spree::DefaultPrice

    belongs_to :product, touch: true, class_name: 'Spree::Product', inverse_of: :variants
    belongs_to :tax_category, class_name: 'Spree::TaxCategory'

    delegate_belongs_to :product, :name, :description, :slug, :available_on,
                        :shipping_category_id, :meta_description, :meta_keywords,
                        :shipping_category

    has_many :inventory_units, inverse_of: :variant
    has_many :line_items, inverse_of: :variant
    has_many :orders, through: :line_items

    has_many :stock_items, dependent: :destroy, inverse_of: :variant
    has_many :stock_locations, through: :stock_items
    has_many :stock_movements, through: :stock_items

    has_and_belongs_to_many :option_values, join_table: :spree_option_values_variants
    has_many :images, -> { order(:position) }, as: :viewable, dependent: :destroy, class_name: "Spree::Image"

    has_many :prices,
      class_name: 'Spree::Price',
      dependent: :destroy,
      inverse_of: :variant

    before_validation :set_cost_currency

    validate :check_price

    validates :cost_price, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
    validates :price,      numericality: { greater_than_or_equal_to: 0, allow_nil: true }
    validates_uniqueness_of :sku, allow_blank: true, conditions: -> { where(deleted_at: nil) }

    after_create :create_stock_items
    after_create :set_master_out_of_stock, unless: :is_master?

    after_touch :clear_in_stock_cache

    scope :in_stock, -> { joins(:stock_items).where('count_on_hand > ? OR track_inventory = ?', 0, false) }

    LOCALIZED_NUMBERS = %w(cost_price weight depth width height)

    LOCALIZED_NUMBERS.each do |m|
      define_method("#{m}=") do |argument|
        self[m] = Spree::LocalizedNumber.parse(argument) if argument.present?
      end
    end

    self.whitelisted_ransackable_associations = %w[option_values product prices default_price]
    self.whitelisted_ransackable_attributes = %w[weight sku]

    def self.active(currency = nil)
      joins(:prices).where(deleted_at: nil).where('spree_prices.currency' => currency || Spree::Config[:currency]).where('spree_prices.amount IS NOT NULL')
    end

    def self.having_orders
      joins(:line_items).distinct
    end

    def tax_category
      if self[:tax_category_id].nil?
        product.tax_category
      else
        TaxCategory.find(self[:tax_category_id])
      end
    end

    # returns number of units currently on backorder for this variant.
    def on_backorder
      inventory_units.with_state('backordered').size
    end

    def is_backorderable?
      Spree::Stock::Quantifier.new(self).backorderable?
    end

    def options_text
      values = self.option_values.sort do |a, b|
        a.option_type.position <=> b.option_type.position
      end

      values.to_a.map! do |ov|
        "#{ov.option_type.presentation}: #{ov.presentation}"
      end

      values.to_sentence({ words_connector: ", ", two_words_connector: ", " })
    end

    # Default to master name
    def exchange_name
      is_master? ? name : options_text
    end

    def descriptive_name
      is_master? ? name + ' - Master' : name + ' - ' + options_text
    end

    # use deleted? rather than checking the attribute directly. this
    # allows extensions to override deleted? if they want to provide
    # their own definition.
    def deleted?
      !!deleted_at
    end

    # Product may be created with deleted_at already set,
    # which would make AR's default finder return nil.
    # This is a stopgap for that little problem.
    def product
      Spree::Product.unscoped { super }
    end

    def options=(options = {})
      options.each do |option|
        set_option_value(option[:name], option[:value])
      end
    end

    def set_option_value(opt_name, opt_value)
      # no option values on master
      return if self.is_master

      option_type = Spree::OptionType.where(name: opt_name).first_or_initialize do |o|
        o.presentation = opt_name
        o.save!
      end

      current_value = self.option_values.detect { |o| o.option_type.name == opt_name }

      unless current_value.nil?
        return if current_value.name == opt_value
        self.option_values.delete(current_value)
      else
        # then we have to check to make sure that the product has the option type
        unless self.product.option_types.include? option_type
          self.product.option_types << option_type
        end
      end

      option_value = Spree::OptionValue.where(option_type_id: option_type.id, name: opt_value).first_or_initialize do |o|
        o.presentation = opt_value
        o.save!
      end

      self.option_values << option_value
      self.save
    end

    def option_value(opt_name)
      self.option_values.detect { |o| o.option_type.name == opt_name }.try(:presentation)
    end

    def price_in(currency)
      prices.detect { |price| price.currency == currency } || Spree::Price.new(variant_id: id, currency: currency)
    end

    def amount_in(currency)
      price_in(currency).try(:amount)
    end

    def price_modifier_amount_in(currency, options = {})
      return 0 unless options.present?

      options.keys.map { |key|
        m = "#{key}_price_modifier_amount_in".to_sym
        if self.respond_to? m
          self.send(m, currency, options[key])
        else
          0
        end
      }.sum
    end

    def price_modifier_amount(options = {})
      return 0 unless options.present?

      options.keys.map { |key|
        m = "#{key}_price_modifier_amount".to_sym
        if self.respond_to? m
          self.send(m, options[key])
        else
          0
        end
      }.sum
    end

    def name_and_sku
      "#{name} - #{sku}"
    end

    def sku_and_options_text
      "#{sku} #{options_text}".strip
    end

    def in_stock?
      Rails.cache.fetch(in_stock_cache_key) do
        total_on_hand > 0
      end
    end

    def can_supply?(quantity=1)
      Spree::Stock::Quantifier.new(self).can_supply?(quantity)
    end

    def total_on_hand
      Spree::Stock::Quantifier.new(self).total_on_hand
    end

    # Shortcut method to determine if inventory tracking is enabled for this variant
    # This considers both variant tracking flag and site-wide inventory tracking settings
    def should_track_inventory?
      self.track_inventory? && Spree::Config.track_inventory_levels
    end

    def track_inventory
      self.should_track_inventory?
    end

    def volume
      (width || 0) * (height || 0) * (depth || 0)
    end

    def dimension
      (width || 0) + (height || 0) + (depth || 0)
    end

    private

      def set_master_out_of_stock
        if product.master && product.master.in_stock?
          product.master.stock_items.update_all(:backorderable => false)
          product.master.stock_items.each { |item| item.reduce_count_on_hand_to_zero }
        end
      end

      # Ensures a new variant takes the product master price when price is not supplied
      def check_price
        if price.nil? && Spree::Config[:require_master_price]
          raise 'No master variant found to infer price' unless (product && product.master)
          raise 'Must supply price for variant or master.price for product.' if self == product.master
          self.price = product.master.price
        end
        if currency.nil?
          self.currency = Spree::Config[:currency]
        end
      end

      def set_cost_currency
        self.cost_currency = Spree::Config[:currency] if cost_currency.nil? || cost_currency.empty?
      end

      def create_stock_items
        StockLocation.where(propagate_all_variants: true).each do |stock_location|
          stock_location.propagate_variant(self)
        end
      end

      def in_stock_cache_key
        "variant-#{id}-in_stock"
      end

      def clear_in_stock_cache
        Rails.cache.delete(in_stock_cache_key)
      end
  end
end
