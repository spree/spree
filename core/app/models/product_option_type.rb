class ProductOptionType < ActiveRecord::Base
  belongs_to :product
  belongs_to :option_type
  acts_as_list :scope => :product
  
  before_save :set_product_variants_to_first_option_value
  
  
  private
  
  def set_product_variants_to_first_option_value
    product.variants.each do |variant|
      variant.option_values << option_type.option_values.first
    end
  end
end