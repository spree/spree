# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class <%= class_name %> < Spree::Extension
  version "1.0"
  description "Describe your extension here"
  url "http://yourwebsite.com/<%= file_name %>"
  
  # define_routes do |map|
  #   map.connect 'admin/<%= file_name %>/:action', :controller => 'admin/<%= file_name %>'
  # end
  
  def activate
    # admin.tabs.add "<%= extension_name %>", "/admin/<%= file_name %>", :after => "Layouts", :visibility => [:all]
  end
  
  def deactivate
    # admin.tabs.remove "<%= extension_name %>"
  end
  
end