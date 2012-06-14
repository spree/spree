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
  has_many :product_properties, :dependent => :destroy, :attributes => true
  has_many :properties, :through => :product_properties
  has_many :images, :as => :viewable, :order => :position, :dependent => :destroy
  has_and_belongs_to_many :product_groups
  belongs_to :tax_category
  has_and_belongs_to_many :taxons
  belongs_to :shipping_category

  has_one :master,
    :class_name => 'Variant',
    :conditions => ["variants.is_master = ? AND variants.deleted_at IS NULL", true]

  delegate_belongs_to :master, :sku, :price, :weight, :height, :width, :depth, :is_master
  delegate_belongs_to :master, :cost_price if Variant.table_exists? && Variant.column_names.include?("cost_price")

  after_create :set_master_variant_defaults
  after_create :add_properties_and_option_types_from_prototype
  before_save :recalculate_count_on_hand
  after_save :update_memberships if ProductGroup.table_exists?
  after_save :set_master_on_hand_to_zero_when_product_has_variants
  after_save :save_master

  has_many :variants,
    :conditions => ["variants.is_master = ? AND variants.deleted_at IS NULL", false]


  has_many :variants_including_master,
    :class_name => 'Variant',
    :conditions => ["variants.deleted_at IS NULL"],
    :dependent => :destroy

  validates_presence_of :name
  validates_presence_of :price

  accepts_nested_attributes_for :product_properties

  make_permalink

  alias :options :product_option_types

  cattr_accessor :search_scopes do
    []
  end

  def self.add_search_scope(name, &block)
    self.named_scope name.intern, &block
    search_scopes << name.intern
  end

  include ::Scopes::Product

  # default product scope only lists available and non-deleted products
  named_scope :active,      lambda { |*args| Product.not_deleted.available(args.first).scope(:find) }
  named_scope :on_hand,     { :conditions => "products.count_on_hand > 0" }
  named_scope :not_deleted, { :conditions => "products.deleted_at is null" }
  named_scope :available,   lambda { |*args| { :conditions => ["products.available_on <= ?", args.first || Time.zone.now] } }

  if (ActiveRecord::Base.connection.adapter_name == 'PostgreSQL')
    named_scope :group_by_products_id, { :group => "products." + Product.column_names.join(", products.") } if ActiveRecord::Base.connection.tables.include?("products")
  else
    named_scope :group_by_products_id, { :group => "products.id" }
  end


  # truncate a list of results (TODO: move this into a superclass)
  named_scope :limit, lambda {|n| {:limit => n}}

  # ----------------------------------------------------------------------------------------------------------
  #
  # The following methods are deprecated and will be removed in a future version of Spree
  #
  # ----------------------------------------------------------------------------------------------------------

  def master_price
    warn "[DEPRECATION] `Product.master_price` is deprecated.  Please use `Product.price` instead. (called from #{caller[0]})"
    self.price
  end

  def master_price=(value)
    warn "[DEPRECATION] `Product.master_price=` is deprecated.  Please use `Product.price=` instead. (called from #{caller[0]})"
    self.price = value
  end

  def variants?
    warn "[DEPRECATION] `Product.variants?` is deprecated.  Please use `Product.has_variants?` instead. (called from #{caller[0]})"
    self.has_variants?
  end

  def variant
    warn "[DEPRECATION] `Product.variant` is deprecated.  Please use `Product.master` instead. (called from #{caller[0]})"
    self.master
  end

  # ----------------------------------------------------------------------------------------------------------
  # end deprecation region
  # ----------------------------------------------------------------------------------------------------------

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
    raise "cannot set on_hand of product with variants" if has_variants? && Spree::Config[:track_inventory_levels]
    master.on_hand = new_level
  end

  # Returns true if there are inventory units (any variant) with "on_hand" state for this product
  def has_stock?
    master.in_stock? || !!variants.detect{|v| v.in_stock?}
  end

  def tax_category
    if self[:tax_category_id].nil?
      TaxCategory.first(:conditions => {:is_default => true})
    else
      TaxCategory.find(self[:tax_category_id])
    end
  end

  # Adding properties and option types on creation based on a chosen prototype
  attr_reader :prototype_id
  def prototype_id=(value)
    @prototype_id = value.to_i
  end

  def add_properties_and_option_types_from_prototype
    if prototype_id and prototype = Prototype.find_by_id(prototype_id)
      prototype.properties.each do |property|
        product_properties.create(:property => property)
      end
      self.option_types = prototype.option_types
    end
  end

  # for adding products which are closely related to existing ones
  # define "duplicate_extra" for site-specific actions, eg for additional fields
  def duplicate
    p = self.clone
    p.name = 'COPY OF ' + self.name
    p.deleted_at = nil
    p.created_at = p.updated_at = nil
    p.taxons = self.taxons

    p.product_properties = self.product_properties.map {|q| r = q.clone; r.created_at = r.updated_at = nil; r}

    image_clone = lambda {|i| j = i.clone; j.attachment = i.attachment.clone; j}
    p.images = self.images.map {|i| image_clone.call i}

    variant = self.master.clone
    variant.sku = 'COPY OF ' + self.master.sku
    variant.deleted_at = nil
    variant.images = self.master.images.map {|i| image_clone.call i}
    p.master = variant

    if self.has_variants?
      # don't clone the actual variants, just the characterising types
      p.option_types = self.option_types
    else
    end
    # allow site to do some customization
    p.send(:duplicate_extra) if p.respond_to?(:duplicate_extra)
    p.save!
    p
  end

  # use deleted? rather than checking the attribute directly. this
  # allows extensions to override deleted? if they want to provide
  # their own definition.
  def deleted?
    !!deleted_at
  end

  # split variants list into hash which shows mapping of opt value onto matching variants
  # eg categorise_variants_from_option(color) => {"red" -> [...], "blue" -> [...]}
  def categorise_variants_from_option(opt_type)
    return {} unless option_types.include?(opt_type)
    variants.active.group_by {|v| v.option_values.detect {|o| o.option_type == opt_type} }
  end

  private

  def recalculate_count_on_hand
    product_count_on_hand = has_variants? ?
        variants.inject(0) {|acc, v| acc + v.count_on_hand} :
        (master ? master.count_on_hand : 0)
    self.count_on_hand = product_count_on_hand
  end

  # the master on_hand is meaningless once a product has variants as the inventory
  # units are now "contained" within the product variants
  def set_master_on_hand_to_zero_when_product_has_variants
    master.on_hand = 0 if has_variants? && Spree::Config[:track_inventory_levels]
  end

  # ensures the master variant is flagged as such
  def set_master_variant_defaults
    master.is_master = true
  end

  # there's a weird quirk with the delegate stuff that does not automatically save the delegate object
  # when saving so we force a save using a hook.
  def save_master
    master.save if master && (master.changed? || master.new_record?)
  end

  def update_memberships
    self.product_groups = ProductGroup.all.select{|pg| pg.include?(self)}
  end
end
