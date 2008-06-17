# Uncomment this if you reference any of your controllers in activate
require_dependency 'application'

class LanguageChooserExtension < Spree::Extension
  version "0.1"
  description "Allows users to change the application language"
  # url "http://yourwebsite.com/language_chooser"

  define_routes do |map|
    map.resource :locale
    # map.namespace :admin do |admin|
    #   admin.resources :whatever
    # end  
  end
  
  def activate
    ApplicationController.send :include, LanguageChooser
    # admin.tabs.add "Language Chooser", "/admin/language_chooser", :after => "Layouts", :visibility => [:all]
  end
  
  def deactivate
    # admin.tabs.remove "Language Chooser"
  end
  
end
