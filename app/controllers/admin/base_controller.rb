class Admin::BaseController < Spree::BaseController
  helper :search
  layout 'admin'
  
  before_filter :initialize_product_admin_tabs
  
  #used to add tabs / partials to product admin interface
  def initialize_product_admin_tabs
    @product_admin_tabs = []
  end
end
