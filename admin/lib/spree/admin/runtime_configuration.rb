module Spree
  module Admin
    class RuntimeConfiguration < ::Spree::Preferences::RuntimeConfiguration
      preference :admin_path, :string, default: '/admin'
      preference :admin_show_version, :boolean, default: true
    end
  end
end
