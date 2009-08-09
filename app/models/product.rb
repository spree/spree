# PRODUCTS
# Products represent an entity for sale in a store.  
# Products can have variations, called variants 
# Products properties include description, permalink, availability, 
#   shipping category, etc. that do not change by variant.
#
# MASTER VARIANT 
# Every product has one master variant, which stores master price and sku, size and weight, etc.
# The master variant does not have option values associated with it.
# Price, SKU, size, weight, etc. are all delegated to the master variant.
# Contains on_hand inventory levels only when there are no variants for the product.
#
# VARIANTS
# All variants can access the product properties directly (via reverse delegation).
# Inventory units are tied to Variant.
# The master variant can have inventory units, but not option values.
# All other variants have option values and may have inventory units.
# Sum of on_hand each variant's inventory level determine "on_hand" level for the product.
# 
class Product < ActiveRecord::Base
  has_many :product_option_types, :dependent => :destroy
  has_many :option_types, :through => :product_option_types
  has_many :variants, :dependent => :destroy
  has_many :product_properties, :dependent => :destroy, :attributes => true
  has_many :properties, :through => :product_properties
	has_many :images, :as => :viewable, :order => :position, :dependent => :destroy
	
  belongs_to :tax_category
  has_and_belongs_to_many :taxons
  belongs_to :shipping_category
  
  has_one :master, 
    :class_name => 'Variant', 
    :conditions => ["is_master = ?", true], 
    :dependent => :destroy
  delegate_belongs_to :master, :sku, :price, :weight, :height, :width, :depth, :is_master
  after_create :set_master_variant_defaults
  after_save :set_master_on_hand_to_zero_when_product_has_variants    
  after_save :save_master
  
  has_many :variants, 
    :conditions => ["is_master = ?", false], 
    :dependent => :destroy

    validates_presence_of :name
    validates_presence_of :price

  accepts_nested_attributes_for :product_properties
  
  make_permalink

  alias :options :product_option_types

  # default product scope only lists available and non-deleted products
  named_scope :active,      lambda { |*args| Product.not_deleted.available(args.first).scope(:find) }

  named_scope :not_deleted,                  { :conditions => "products.deleted_at is null" }
  named_scope :available,   lambda { |*args| { :conditions => ["products.available_on <= ?", args.first || Time.zone.now] } }

  named_scope :master_price_between, lambda {|low,high| 
    { :conditions => ["master_price BETWEEN ? AND ?", low, high] }
  }

  named_scope :taxons_id_in_tree, lambda {|taxon| 
    Product.taxons_id_in_tree_any(taxon).scope :find 
  }

  # TODO - speed test on nest vs join
  named_scope :taxons_id_in_tree_any, lambda {|*taxons| 
    taxons = [taxons].flatten
    { :conditions => [ "products.id in (select product_id from products_taxons where taxon_id in (?))", 
                       taxons.map    {|i| i.is_a?(Taxon) ? i : Taxon.find(i)}.
                              reject {|t| t.nil?}.
                              map    {|t| [t] + t.descendents}.flatten ]}
  }

  # a simple test for product with a certain property-value pairing
  # it can't test for NULLs and can't be cascaded - see :with_property 
  named_scope :with_property_value, lambda { |property, value| 
    Product.product_properties_property_id_equals(property).
            product_properties_value_equals(value).
            scope :find
  }   # coded this way to demonstrate composition


  # a scope which sets up later testing on the values of a given property
  # it takes * a property (object or id), and 
  #          * an optional distinguishing name to support multiple property tests 
  # this version includes results for which the property is not given (ie is NULL),
  #   eg an unspecified colour would come out as a NULL.
  # it probably won't be used without taxon or other filters having narrowed the set 
  #   to a point where results aren't swamped by nulls, hence no inner join version
  named_scope :with_property,
    lambda {|property,*args|
      name = args.empty? ? "product_properties" : args.first
      property_id = case property
                      when Property then property.id 
                      when Fixnum   then property
                    end
      return {} if property_id.nil?
      { :joins => "left outer join product_properties #{name} on products.id = #{name}.product_id and #{name}.property_id = #{property_id}"}
    }
                     

  # add in option_values_variants to the query
  # this is the common info required for all options searches
  named_scope :with_variant_options,
    Product.
      scoped(:joins => :variants).
      scoped(:joins => "join option_values_variants on variants.id = option_values_variants.variant_id").
      scope(:find)

  # select products which have an option of the given type
  # this sets up testing on specific option values, eg colour = red
  # the optional argument supports filtering by multi options, eg colour = red and 
  #   size = small, which need separate joins if done a property at a time
  # this version discards products which don't have the given option (the outer join
  #   version is a bit more complex because we need to control the order of joins)
  # TODO: speed test on nest vs join
  named_scope :with_option,
    lambda {|opt_type,*args|
      name   = args.empty? ? "option_types" : args.first
      opt_id = case opt_type
                 when OptionType then opt_type.id 
                 when Fixnum     then opt_type
               end
      return {} if opt_id.nil?
      Product.with_variant_options.
              scoped(:joins => "join (select presentation, id from option_values where option_type_id = #{opt_id}) #{name} on #{name}.id = option_values_variants.option_value_id").
              scope(:find)
    }

  # ----------------------------------------------------------------------------------------------------------
  #
  # The following methods are deprecated and will be removed in a future version of Spree
  # 
  # ----------------------------------------------------------------------------------------------------------
  
  def master_price
    warn "[DEPRECATION] `Product.master_price` is deprecated.  Please use `Product.price` instead." unless RAILS_ENV == 'test'
    self.price
  end
  
  def master_price=(value)
    warn "[DEPRECATION] `Product.master_price=` is deprecated.  Please use `Product.price=` instead."
    self.price = value
  end
  
  def variants?
    warn "[DEPRECATION] `Product.variants?` is deprecated.  Please use `Product.has_variants?` instead."
    self.has_variants?
  end
  
  def variant
    warn "[DEPRECATION] `Product.variant` is deprecated.  Please use `Product.master` instead."
    self.master
  end

  def to_param       
    return permalink unless permalink.blank?
    name.to_url
  end
  
  # returns true if the product has any variants (the master variant is not a member of the variants array)
  def has_variants?
    !variants.empty?
  end

  # returns the number of inventory units "on_hand" for this product
  def on_hand
    has_variants? ? variants.inject(0){|sum, v| sum + v.on_hand} : master.on_hand
  end

  # adjusts the "on_hand" inventory level for the product up or down to match the given new_level
  def on_hand=(new_level)
    raise "cannot set on_hand of product with variants" if has_variants?
    master.on_hand = new_level
  end

  # Returns true if there are inventory units (any variant) with "on_hand" state for this product
  def has_stock?
    master.in_stock? || !!variants.detect{|v| v.in_stock?}
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

  # the master on_hand is meaningless once a product has variants as the inventory
  # units are now "contained" within the product variants
  def set_master_on_hand_to_zero_when_product_has_variants
    master.on_hand = 0 if has_variants?
  end

  # ensures the master variant is flagged as such
  def set_master_variant_defaults
    master.is_master = true
  end      
  
  # there's a weird quirk with the delegate stuff that does not automatically save the delegate object
  # when saving so we force a save using a hook.
  def save_master
    master.save if master
  end
end
