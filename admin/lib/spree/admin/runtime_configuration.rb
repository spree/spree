require 'spree/core/preferences/runtime_configuration'
require 'kaminari'

module Spree
  module Admin
    class RuntimeConfiguration < ::Spree::Preferences::RuntimeConfiguration
      preference :admin_path, :string, default: '/admin'
      preference :admin_updater_enabled, :boolean, default: true

      preference :admin_records_per_page, :integer, default: Kaminari.config.default_per_page
      preference :admin_products_per_page, :integer, default: Kaminari.config.default_per_page
      preference :admin_orders_per_page, :integer, default: Kaminari.config.default_per_page

      preference :include_application_importmap, :boolean, default: false
    end
  end
end
