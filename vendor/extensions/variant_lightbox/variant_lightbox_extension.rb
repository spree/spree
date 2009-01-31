# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class VariantLightboxExtension < Spree::Extension
  version "1.0"
  description "Describe your extension here"
  url "http://yourwebsite.com/variant_lightbox"

  # Please use variant_lightbox/config/routes.rb instead for extension routes.

  # def self.require_gems(config)
  #   config.gem "gemname-goes-here", :version => '1.2.3'
  # end
  
  def activate
    # admin.tabs.add "Variant Lightbox", "/admin/variant_lightbox", :after => "Layouts", :visibility => [:all]
    Product.class_eval do
      #Override thumbnail view here
    end
  end
end
