class Admin::BaseController < Spree::BaseController
  helper :search
  layout 'admin'
  
  before_filter :initialize_product_admin_tabs
  before_filter :initialize_order_admin_tabs
  
  #used to add tabs / partials to product admin interface
  def initialize_product_admin_tabs
    @product_admin_tabs = []
  end

  #used to add tabs / partials to order admin interface
  def initialize_order_admin_tabs
    @order_admin_tabs = []
  end
end
