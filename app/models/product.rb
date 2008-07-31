class Product < ActiveRecord::Base
  has_many :product_option_types, :dependent => :destroy
  has_many :option_types, :through => :product_option_types
  has_many :variants, :dependent => :destroy
  has_many :images, :as => :viewable, :order => :position, :dependent => :destroy
  has_many :property_values
  belongs_to :tax_category

  validates_presence_of :name
  validates_presence_of :master_price
  validates_presence_of :description

  make_permalink :with => :name, :field => :permalink

  alias :options :product_option_types

  named_scope :available, lambda {|*args| {:conditions => ["available_on <= ?", (args.first || Time.now)]}}
  named_scope :by_name, lambda {|name| {:conditions => ["name like ?", "%#{name}%"]}}
  named_scope :by_sku, lambda {|sku| { :include => :variants, :conditions => ["variants.sku like ?", "%#{sku}%"]}}
  

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
    #variant.on_hand(quantity)
  end
end
