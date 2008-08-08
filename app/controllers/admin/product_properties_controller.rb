class Admin::ProductPropertiesController < Admin::BaseController
  resource_controller
  
  # note: we're using attribute_fu to manage the product_properties so the products controller will be 
  # doing most of the work  
  belongs_to :product
end
