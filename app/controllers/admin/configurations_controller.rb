class Admin::ConfigurationsController < Admin::BaseController

  before_filter :initialize_extension_links, :only => :index
  before_filter :add_shipping_links, :only => :index

  protected

  def add_shipping_links
    @extension_links << {:link => admin_shipping_methods_path, :link_text => t("shipping_methods"), :description => t("shipping_methods_description")}
    @extension_links << {:link => admin_shipping_categories_path, :link_text => t("shipping_categories"), :description => t("shipping_categories_description")}
  end

  def initialize_extension_links
    @extension_links = []
  end
end
