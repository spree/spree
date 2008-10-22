# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class FooExtension < Spree::Extension
  version "1.0"
  description "Describe your extension here"
  url "http://yourwebsite.com/foo"

  # define_routes do |map|
  #   map.namespace :admin do |admin|
  #     admin.resources :whatever
  #   end  
  # end
  
  def activate
    # admin.tabs.add "Foo", "/admin/foo", :after => "Layouts", :visibility => [:all]
  end
  
  def deactivate
    # admin.tabs.remove "Foo"
  end
  
end