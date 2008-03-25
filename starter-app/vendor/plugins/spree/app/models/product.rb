class Product < ActiveRecord::Base
  has_many :product_option_types, :dependent => :destroy
  has_many :option_types, :through => :product_option_types
  has_many :variants, :dependent => :destroy
  belongs_to :category
  has_and_belongs_to_many :tax_treatments
  has_many :images, :as => :viewable, :dependent => :destroy
  has_one :sku, :as => :stockable, :dependent => :destroy
  validates_presence_of :name
  validates_presence_of :description
  validates_presence_of :price
  
  alias :selected_options :product_option_types
  
  # if product has a new category then we may need to delete tax_treatments associated with the  
  # previous category
  def before_update
    return if self.category.nil?
    ar_tax_treatments.clear unless self.category.tax_treatments.empty? 
  end
  
  def apply_tax_treatment?(id)
    return true if self.tax_treatments.any? {|tt| tt.id == id} 
    return self.category.tax_treatments.any? {|tt| tt.id == id} unless self.category.nil?
  end

  # Serious Ruby hacking going on here.  We alias the original method for the association as added by 
  # ActiveRecord and then override it so we can return the categories treatments if they are present.
  alias :ar_tax_treatments :tax_treatments
  def tax_treatments
    tt = ar_tax_treatments
    return tt unless tt.empty?
    return tt if self.category.nil?
    if self.category.tax_treatments.empty?
      # return empty array (does not need to be frozen since category has none)
      return tt
    else
      # return a frozen copy of the category tax treatments
      return Array.new(self.category.tax_treatments).freeze   
    end
  end  
end