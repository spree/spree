module Spree
  class Variant < ActiveRecord::Base
    belongs_to :product
    delegate_belongs_to :product, :name, :description, :permalink, :available_on,
                        :tax_category_id, :shipping_category_id, :meta_description,
                        :meta_keywords, :tax_category

    attr_accessible :name, :presentation, :cost_price,
                    :position, :on_hand, :option_value_ids,
                    :product_id, :option_values_attributes, :price,
                    :weight, :height, :width, :depth, :sku

    has_many :inventory_units
    has_many :line_items
    has_and_belongs_to_many :option_values, :join_table => 'spree_option_values_variants'
    has_many :images, :as => :viewable, :order => :position, :dependent => :destroy

    validate :check_price
    validates :price, :numericality => { :greater_than_or_equal_to => 0 }, :presence => true
    validates :cost_price, :numericality => { :greater_than_or_equal_to => 0, :allow_nil => true } if self.table_exists? && self.column_names.include?('cost_price')
    validates :count_on_hand, :numericality => true

    before_save :touch_product

    # default variant scope only lists non-deleted variants
    scope :active, where(:deleted_at => nil)
    scope :deleted, where('deleted_at IS NOT NULL')

    # default extra fields for shipping purposes
    @fields = [{ :name => 'Weight', :only => [:variant], :format => '%.2f' },
               { :name => 'Height', :only => [:variant], :format => '%.2f' },
               { :name => 'Width',  :only => [:variant], :format => '%.2f' },
               { :name => 'Depth',  :only => [:variant], :format => '%.2f' }]

    # Returns number of inventory units for this variant (new records haven't been saved to database, yet)
    def on_hand
      Spree::Config[:track_inventory_levels] ? count_on_hand : (1.0 / 0) # Infinity
    end

    # Adjusts the inventory units to match the given new level.
    def on_hand=(new_level)
      if Spree::Config[:track_inventory_levels]
        new_level = new_level.to_i

        # increase Inventory when
        if new_level > on_hand
          # fill backordered orders before creating new units
          backordered_units = inventory_units.with_state('backordered')
          backordered_units.slice(0, new_level).each(&:fill_backorder)
          new_level -= backordered_units.length
        end

        self.count_on_hand = new_level
      else
        raise 'Cannot set on_hand value when Spree::Config[:track_inventory_levels] is false'
      end
    end

    # strips all non-price-like characters from the price.
    def price=(price)
      if price.present?
        self[:price] = price.to_s.gsub(/[^0-9\.-]/, '').to_f
      end
    end

    # and cost_price
    def cost_price=(price)
      if price.present?
        self[:cost_price] = price.to_s.gsub(/[^0-9\.-]/, '').to_f
      end
    end

    # returns number of units currently on backorder for this variant.
    def on_backorder
      inventory_units.with_state('backordered').size
    end

    # returns true if at least one inventory unit of this variant is "on_hand"
    def in_stock?
      Spree::Config[:track_inventory_levels] ? on_hand > 0 : true
    end
    alias in_stock in_stock?

    # returns true if this variant is allowed to be placed on a new order
    def available?
      Spree::Config[:track_inventory_levels] ? (Spree::Config[:allow_backorders] || in_stock?) : true
    end

    def options_text
      values = self.option_values.sort_by(&:position)

      values.map! do |ov|
        "#{ov.option_type.presentation}: #{ov.presentation}"
      end

      values.to_sentence({ :words_connector => ", ", :two_words_connector => ", " })
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

      option_type = Spree::OptionType.find_or_initialize_by_name(opt_name) do |o|
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

      option_value = Spree::OptionValue.find_or_initialize_by_option_type_id_and_name(option_type.id, opt_value) do |o|
        o.presentation = opt_value
        o.save!
      end

      self.option_values << option_value
      self.save
    end

    def option_value(opt_name)
      self.option_values.detect { |o| o.option_type.name == opt_name }.try(:presentation)
    end

    private
      # Ensures a new variant takes the product master price when price is not supplied
      def check_price
        if price.nil?
          raise 'Must supply price for variant or master.price for product.' if self == product.master
          self.price = product.master.price
        end
      end

      def touch_product
        product.touch unless is_master?
      end
  end
end

require_dependency 'spree/variant/scopes'
