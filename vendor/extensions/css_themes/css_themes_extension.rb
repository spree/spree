# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class CssThemesExtension < Spree::Extension
  version "1.0"
  description "Describe your extension here"
  url "http://yourwebsite.com/css_themes"

  # Please use css_themes/config/routes.rb instead for extension routes.

  # def self.require_gems(config)
  #   config.gem "gemname-goes-here", :version => '1.2.3'
  # end
  
  def activate
    Admin::ConfigurationsController.class_eval do
      before_filter :add_theme_links, :only => :index
      def add_theme_links
        @extension_links << {:link => admin_themes_path, :link_text => "Themes", :description => "Edit Themes" }
      end
    end

    ContentController.class_eval do
      before_filter :add_theme_stylesheet
      def add_theme_stylesheet
        @testyo << 'test123'
      end
    end
  end
end
