require 'spree/core/preferences/runtime_configuration'

module Spree
  module Admin
    class RuntimeConfiguration < ::Spree::Preferences::RuntimeConfiguration
      DEFAULT_PER_PAGE = 25

      preference :admin_path, :string, default: '/admin'
      preference :admin_updater_enabled, :boolean, default: true

      preference :admin_records_per_page, :integer, default: DEFAULT_PER_PAGE
      preference :admin_products_per_page, :integer, default: DEFAULT_PER_PAGE
      preference :admin_orders_per_page, :integer, default: DEFAULT_PER_PAGE

      preference :include_application_importmap, :boolean, default: false
      preference :legacy_sidebar_navigation, :boolean, default: false

      preference :reports_line_items_limit, :integer, default: 1000
    end
  end
end
