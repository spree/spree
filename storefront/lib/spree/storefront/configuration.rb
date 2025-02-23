require 'spree/core/preferences/runtime_configuration'

module Spree
  module Storefront
    class Configuration < ::Spree::Preferences::RuntimeConfiguration
      preference :products_per_page, :integer, default: 20

    end
  end
end
