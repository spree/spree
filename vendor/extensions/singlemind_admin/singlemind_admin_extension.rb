# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class SinglemindAdminExtension < Spree::Extension
  version "1.0"
  description "Describe your extension here"
  url "http://yourwebsite.com/singlemind_admin"

  # Please use singlemind_admin/config/routes.rb instead for extension routes.

  # def self.require_gems(config)
  #   config.gem "gemname-goes-here", :version => '1.2.3'
  # end
  
  def activate
    # admin.tabs.add "Singlemind Admin", "/admin/singlemind_admin", :after => "Layouts", :visibility => [:all]
  end
end