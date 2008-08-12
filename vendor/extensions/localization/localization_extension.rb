# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class LocalizationExtension < Spree::Extension
  version "0.1.1"
  description "Localization support for Spree"
  url "http://support.spreehq.org/wiki/1/I18n"

  define_routes do |map|
    map.set_locale '/locale/set', :controller => 'locale', :action => 'set', :method => :get
    map.namespace :admin do |admin|
      admin.resource :localization, :controller => 'admin/localization'
    end  
  end
  
  def activate
    ApplicationController.class_eval do
      include Localization
      helper_method :t
    end

    User.class_eval do
      include Localization::UserPreferences
    end

    # admin.tabs.add "Localization", "/admin/localization", :after => "Layouts", :visibility => [:all]
  end
  
  def deactivate
    # admin.tabs.remove "Localization"
  end
  
end
