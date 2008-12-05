class Admin::ProductPropertiesController < Admin::BaseController
  resource_controller
  before_filter :initialize_product_extensions
  
  # note: we're using attribute_fu to manage the product_properties so the products controller will be 
  # doing most of the work  
  belongs_to :product
end
