class Admin::ConfigurationsController < Admin::BaseController
  before_filter :initialize_extension_links, :only => :index
  
  class << self
    def add_link(text, path, description)
      unless @@extension_links.any?{|link| link[:link_text] == text}
        @@extension_links << {
          :link => path,
          :link_text => text,
          :description => description,
        }
      end
    end
  end

  protected

  def initialize_extension_links
    @extension_links = [
      {:link => admin_shipping_methods_path, :link_text => t("shipping_methods"), :description => t("shipping_methods_description")},
      {:link => admin_shipping_categories_path, :link_text => t("shipping_categories"), :description => t("shipping_categories_description")},
    ] + @@extension_links
  end

  @@extension_links = []
end
