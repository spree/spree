class Admin::BaseController < Spree::BaseController
  helper :search
  layout 'admin'

  before_filter :initialize_product_admin_tabs
  before_filter :initialize_order_admin_tabs
  before_filter :initialize_extension_tabs
  before_filter :add_shipments_tab
  before_filter :parse_date_params

protected

  def render_js_for_destroy
    render :js => "$('.flash.notice').html('#{flash[:notice]}'); $('.flash.notice').show();"
    flash[:notice] = nil
  end

private
  def parse_date_params
    params.each do |k, v|
      parse_date_params_for(v) if v.is_a?(Hash)
    end
  end

  def parse_date_params_for(hash)
    dates = []
    hash.each do |k, v|
      parse_date_params_for(v) if v.is_a?(Hash)
      if k =~ /\(\di\)$/
        param_name = k[/^\w+/]
        dates << param_name
      end
    end
    if (dates.size > 0)
      dates.uniq.each do |date|
        hash[date] = [hash.delete("#{date}(2i)"), hash.delete("#{date}(3i)"), hash.delete("#{date}(1i)")].join('/')
      end
    end
  end

  def add_extension_admin_tab(*tab_args)
    @extension_tabs << tab_args.flatten
  end

  def initialize_extension_tabs
    @extension_tabs = []
  end

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

