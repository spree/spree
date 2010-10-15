class Variant < ActiveRecord::Base
  belongs_to :product
  delegate_belongs_to :product, :name, :description, :permalink, :available_on, :tax_category_id, :shipping_category_id, :meta_description, :meta_keywords

  has_many :inventory_units
  has_many :line_items
  has_and_belongs_to_many :option_values
  has_many :images, :as => :viewable, :order => :position, :dependent => :destroy

  validate :check_price
  validates :price, :presence => true
  validates :cost_price, :numericality => true, :allow_nil => true if Variant.table_exists? && Variant.column_names.include?("cost_price")

  before_save :touch_product

  include ::Scopes::Variant
  # default variant scope only lists non-deleted variants
  scope :active, where("variants.deleted_at is null")
  scope :deleted, where("not variants.deleted_at is null")

  # default extra fields for shipping purposes
  @fields = [ {:name => 'Weight', :only => [:variant], :format => "%.2f"},
              {:name => 'Height', :only => [:variant], :format => "%.2f"},
              {:name => 'Width',  :only => [:variant], :format => "%.2f"},
              {:name => 'Depth',  :only => [:variant], :format => "%.2f"} ]

  # Returns number of inventory units for this variant (new records haven't been saved to database, yet)
  def on_hand
    Spree::Config[:track_inventory_levels] ? self.count_on_hand : nil
  end

  # Adjusts the inventory units to match the given new level.
  def on_hand=(new_level)
    if Spree::Config[:track_inventory_levels]
      new_level = new_level.to_i

      # increase Inventory when
      if new_level > on_hand
        # fill backordered orders before creating new units
        inventory_units.with_state("backordered").slice(0, new_level).each do |iu|
          iu.fill_backorder
          new_level -= 1
        end
      end

      self.count_on_hand = new_level
    else
      raise "Cannot set on_hand value when Spree::Config[:track_inventory_levels] is false"
    end
  end

  # returns number of units currently on backorder for this variant.
  def on_backorder
    inventory_units.with_state("backordered").size
  end

  # returns true if at least one inventory unit of this variant is "on_hand"
  def in_stock?
    Spree::Config[:track_inventory_levels] ? on_hand > 0 : true
  end
  alias in_stock in_stock?

  def self.additional_fields
    @fields
  end

  def self.additional_fields=(new_fields)
    @fields = new_fields
  end

  # returns true if this variant is allowed to be placed on a new order
  def available?
    Spree::Config[:track_inventory_levels] ? (Spree::Config[:allow_backorders] || self.in_stock?) : true
  end

  def options_text
    self.option_values.map { |ov| "#{ov.option_type.presentation}: #{ov.presentation}" }.to_sentence({:words_connector => ", ", :two_words_connector => ", "})
  end

  def gross_profit
    self.cost_price.nil? ? 0 : (self.price - self.cost_price)
  end

  # use deleted? rather than checking the attribute directly. this
  # allows extensions to override deleted? if they want to provide
  # their own definition.
  def deleted?
    deleted_at
  end

  private

  # Ensures a new variant takes the product master price when price is not supplied
  def check_price
    if self.price.nil?
      raise "Must supply price for variant or master.price for product." if self == product.master
      self.price = product.master.price
    end
  end

  def touch_product
    product.touch unless is_master?
  end
end
