class Admin::BaseController < Spree::BaseController
  helper :search
  layout 'admin'
  
  #used to add tabs / partials to product admin interface
  def initialize_product_extensions
    @product_extensions = []
  end
end
