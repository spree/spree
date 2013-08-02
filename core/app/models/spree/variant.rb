module Spree
  class Variant < ActiveRecord::Base
    acts_as_paranoid

    belongs_to :product, touch: true, class_name: 'Spree::Product'

    delegate_belongs_to :product, :name, :description, :permalink, :available_on,
                        :tax_category_id, :shipping_category_id, :meta_description,
                        :meta_keywords, :tax_category, :shipping_category

    attr_accessible :name, :presentation, :cost_price, :lock_version,
                    :position, :option_value_ids,
                    :product_id, :option_values_attributes, :price,
                    :weight, :height, :width, :depth, :sku, :cost_currency

    has_many :inventory_units
    has_many :line_items

    has_many :stock_items, dependent: :destroy, :order => "id ASC"
    has_many :stock_locations, through: :stock_items
    has_many :stock_movements

    has_and_belongs_to_many :option_values, join_table: :spree_option_values_variants
    has_many :images, as: :viewable, order: :position, dependent: :destroy, class_name: "Spree::Image"

    has_one :default_price,
      class_name: 'Spree::Price',
      conditions: proc { { currency: Spree::Config[:currency] } },
      dependent: :destroy

    delegate_belongs_to :default_price, :display_price, :display_amount, :price, :price=, :currency if Spree::Price.table_exists?

    has_many :prices,
      class_name: 'Spree::Price',
      dependent: :destroy

    validate :check_price
    validates :price, numericality: { greater_than_or_equal_to: 0 }, presence: true, if: proc { Spree::Config[:require_master_price] }
    validates :cost_price, numericality: { greater_than_or_equal_to: 0, allow_nil: true } if self.table_exists? && self.column_names.include?('cost_price')

    before_validation :set_cost_currency
    after_save :save_default_price
    after_create :create_stock_items
    after_create :set_position

    # default variant scope only lists non-deleted variants
    scope :deleted, lambda { where('deleted_at IS NOT NULL') }

    def self.active(currency = nil)
      joins(:prices).where(deleted_at: nil).where('spree_prices.currency' => currency || Spree::Config[:currency]).where('spree_prices.amount IS NOT NULL')
    end

    def cost_price=(price)
      self[:cost_price] = parse_price(price) if price.present?
    end

    # returns number of units currently on backorder for this variant.
    def on_backorder
      inventory_units.with_state('backordered').size
    end

    def options_text
      values = self.option_values.joins(:option_type).order("#{Spree::OptionType.table_name}.position asc")

      values.map! do |ov|
        "#{ov.option_type.presentation}: #{ov.presentation}"
      end

      values.to_sentence({ words_connector: ", ", two_words_connector: ", " })
    end

    def gross_profit
      cost_price.nil? ? 0 : (price - cost_price)
    end

    # use deleted? rather than checking the attribute directly. this
    # allows extensions to override deleted? if they want to provide
    # their own definition.
    def deleted?
      deleted_at
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
          self.product.save
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

    def has_default_price?
      !self.default_price.nil?
    end

    def price_in(currency)
      prices.select{ |price| price.currency == currency }.first || Spree::Price.new(variant_id: self.id, currency: currency)
    end

    def amount_in(currency)
      price_in(currency).try(:amount)
    end

    def name_and_sku
      "#{name} - #{sku}"
    end

    def in_stock?(quantity=1)
      Spree::Stock::Quantifier.new(self).can_supply?(quantity)
    end

    def total_on_hand
      Spree::Stock::Quantifier.new(self).total_on_hand
    end

    # Product may be created with deleted_at already set,
    # which would make AR's default finder return nil.
    # This is a stopgap for that little problem.
    def product
      Spree::Product.unscoped { super }
    end

    private
      # strips all non-price-like characters from the price, taking into account locale settings
      def parse_price(price)
        return price unless price.is_a?(String)

        separator, delimiter = I18n.t([:'number.currency.format.separator', :'number.currency.format.delimiter'])
        non_price_characters = /[^0-9\-#{separator}]/
        price.gsub!(non_price_characters, '') # strip everything else first
        price.gsub!(separator, '.') unless separator == '.' # then replace the locale-specific decimal separator with the standard separator if necessary

        price.to_d
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

      def save_default_price
        default_price.save if default_price && (default_price.changed? || default_price.new_record?)
      end

      def set_cost_currency
        self.cost_currency = Spree::Config[:currency] if cost_currency.nil? || cost_currency.empty?
      end

      def create_stock_items
        StockLocation.all.each do |stock_location|
          stock_location.propagate_variant(self) if stock_location.propagate_all_variants?
        end
      end

      def set_position
        self.update_column(:position, product.variants.maximum(:position).to_i + 1)
      end
  end
end

require_dependency 'spree/variant/scopes'
