require 'spree/core/preferences/runtime_configuration'

module Spree
  module Storefront
    class Configuration < ::Spree::Preferences::RuntimeConfiguration
      preference :products_per_page, :integer, default: 20

      preference :search_min_query_length, :integer, default: 2
    end
  end
end
