class Admin::BaseController < Spree::BaseController
  helper :search
  layout 'admin'
  
  before_filter :initialize_product_admin_tabs
  before_filter :initialize_order_admin_tabs
  before_filter :add_shipments_tab

private
  def add_shipments_tab
    @order_admin_tabs << {:name => 'Shipments', :url => "admin_order_shipments_url"}
  end
  
  #used to add tabs / partials to product admin interface
  def initialize_product_admin_tabs
    @product_admin_tabs = []
  end

  #used to add tabs / partials to order admin interface
  def initialize_order_admin_tabs
    @order_admin_tabs = []
  end
end
