class Product < ActiveRecord::Base
  has_many :product_option_types, :dependent => :destroy
  has_many :option_types, :through => :product_option_types
  has_many :variants, :dependent => :destroy
  belongs_to :category
  has_many :images, :as => :viewable, :order => :position, :dependent => :destroy
  has_many :property_values

  validates_presence_of :name
  validates_presence_of :master_price
  validates_presence_of :description

  before_create :empty_variant

  make_permalink :with => :name, :field => :permalink

  alias :selected_options :product_option_types

  named_scope :available, lambda {|*args| {:conditions => ["available_on <= ?", (args.first || Time.now)]}}

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

  private
    # all products must have an "empty variant" (this variant will be ignored if meaningful ones are added later)
    def empty_variant
      self.variants << Variant.new
    end
end
