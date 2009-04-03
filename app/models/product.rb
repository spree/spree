class Product < ActiveRecord::Base
  after_update :adjust_inventory, :adjust_variant_price
  after_create :set_initial_inventory
  
  has_many :product_option_types, :dependent => :destroy
  has_many :option_types, :through => :product_option_types
  has_many :variants, :dependent => :destroy
  has_many :images, :as => :viewable, :order => :position, :dependent => :destroy
  has_many :product_properties, :dependent => :destroy, :attributes => true
  has_many :properties, :through => :product_properties
  belongs_to :tax_category
  has_and_belongs_to_many :taxons
  belongs_to :shipping_category
  

  validates_presence_of :name
  validates_presence_of :master_price

  accepts_nested_attributes_for :product_properties
  
  make_permalink

  alias :options :product_option_types

  # default product scope only lists available and non-deleted products
  named_scope :active, lambda { |*args| { :conditions => ["products.available_on <= ? and products.deleted_at is null", (args.first || Time.zone.now)] } }
  named_scope :not_deleted, lambda { |*args| { :conditions => ["products.deleted_at is null", (args.first || Time.zone.now)] } }
  
  named_scope :available, lambda { |*args| { :conditions => ["products.available_on <= ?", (args.first || Time.zone.now)] } }


  named_scope :with_property_value, lambda { |property_id, value| { :include => :product_properties, :conditions => ["product_properties.property_id = ? AND product_properties.value = ?", property_id, value] } }

                 
  def to_param       
    return permalink unless permalink.blank?
    name.parameterize.to_s
  end
  
  # checks is there are any meaningful variants (ie. variants with at least one option value)
  def variants?
    self.variants.each do |v|
      return true unless v.option_values.empty?
    end
    false
  end

  # special method that returns the single empty variant (but only if there are no meaningful variants)
  def variant
    return nil if variants?
    variants.first
  end
  
  # Pseduo Attribute.  Products don't really have inventory - variants do.  We want to make the variant stuff transparent
  # in the simple cases, however, so we pretend like we're setting the inventory of the product when in fact, we're really 
  # changing the inventory of the so-called "empty variant."
  def on_hand
    variant.on_hand
  end

  def on_hand=(quantity)
    @quantity = quantity
  end
  
  # Pseduo attribute for SKU, similiar as on_hand above.
  def sku
    variant.sku if variant
  end
  
  def sku=(sku)
    variant.sku = sku if variant
  end
  
  def has_stock?
    variants.inject(false){ |tf, v| tf ||= v.in_stock }
  end
  
  
  # Adding properties and option types on creation based on a chosen prototype
  
  attr_reader :prototype_id
  def prototype_id=(value)
    @prototype_id = value.to_i
  end
  after_create :add_properties_and_option_types_from_prototype
  
  def add_properties_and_option_types_from_prototype
    if prototype_id and prototype = Prototype.find_by_id(prototype_id)
      prototype.properties.each do |property|
        product_properties.create(:property => property)
      end
      self.option_types = prototype.option_types
    end
  end
  
  
  
  private

    def adjust_inventory
      return if self.new_record?
      return unless @quantity && @quantity.is_integer?    
      new_level = @quantity.to_i
      # don't allow negative on_hand inventory
      return if new_level < 0
      variant.save
      variant.inventory_units.with_state("backordered").each{|iu|
        if new_level > 0
          iu.fill_backorder
          new_level = new_level - 1
        end
        break if new_level < 1
        }
      
      adjustment = new_level - on_hand
      if adjustment > 0
        InventoryUnit.create_on_hand(variant, adjustment)
        reload
      elsif adjustment < 0
        InventoryUnit.destroy_on_hand(variant, adjustment.abs)
        reload
      end      
    end
  
    def adjust_variant_price
      # If there's a master price change, make sure the empty variant has its price changed as well (Bug #61)
      if master_price_changed?
        variants.first.price = master_price
        variants.first.save
      end
    end
      
    def set_initial_inventory
      return unless @quantity && @quantity.is_integer?    
      variant.save
      level = @quantity.to_i
      InventoryUnit.create_on_hand(variant, level)
      reload
    end
end
