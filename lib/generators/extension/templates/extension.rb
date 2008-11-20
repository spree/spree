# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class <%= class_name %> < Spree::Extension
  version "1.0"
  description "Describe your extension here"
  url "http://yourwebsite.com/<%= file_name %>"

  # Please use <%= file_name %>/config/routes.rb instead for extension routes.

  # def self.require_gems(config)
  #   config.gem "gemname-goes-here", :version => '1.2.3'
  # end
  
  def activate
    # admin.tabs.add "<%= extension_name %>", "/admin/<%= file_name %>", :after => "Layouts", :visibility => [:all]
  end
end