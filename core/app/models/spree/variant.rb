module Spree
  class Variant < Spree::Base
    acts_as_paranoid

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

    validate :check_price

    validates :cost_price, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
    validates :price,      numericality: { greater_than_or_equal_to: 0, allow_nil: true }
    validates_uniqueness_of :sku, allow_blank: true, conditions: -> { where(deleted_at: nil) }

    before_validation :set_cost_currency
    after_create :create_stock_items
    after_create :set_position
    after_create :set_master_out_of_stock, :unless => :is_master?

    after_touch :clear_in_stock_cache

    def self.active(currency = nil)
      joins(:prices).where(deleted_at: nil).where('spree_prices.currency' => currency || Spree::Config[:currency]).where('spree_prices.amount IS NOT NULL')
    end

    def tax_category
      if self[:tax_category_id].nil?
        product.tax_category
      else
        TaxCategory.find(self[:tax_category_id])
      end
    end

    def cost_price=(price)
      self[:cost_price] = Spree::LocalizedNumber.parse(price) if price.present?
    end

    def weight=(weight)
      self[:weight] = Spree::LocalizedNumber.parse(weight) if weight.present?
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
      prices.select{ |price| price.currency == currency }.first || Spree::Price.new(variant_id: self.id, currency: currency)
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
        m = "#{options[key]}_price_modifier_amount".to_sym
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

      def set_position
        self.update_column(:position, product.variants.maximum(:position).to_i + 1)
      end

      def in_stock_cache_key
        "variant-#{id}-in_stock"
      end

      def clear_in_stock_cache
        Rails.cache.delete(in_stock_cache_key)
      end
  end
end

require_dependency 'spree/variant/scopes'
