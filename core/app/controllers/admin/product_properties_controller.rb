class Admin::ProductPropertiesController < Admin::BaseController
  resource_controller
  before_filter :find_properties
  
  # note: we're using attribute_fu to manage the product_properties so the products controller will be 
  # doing most of the work  
  belongs_to :product
  
  private
  
  def find_properties
    @properties = Property.all.map(&:name).join(" ")
  end
end
