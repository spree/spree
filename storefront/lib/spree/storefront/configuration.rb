require 'spree/core/preferences/runtime_configuration'

module Spree
  module Storefront
    class Configuration < ::Spree::Preferences::RuntimeConfiguration
      preference :page_cache_enabled, :boolean, default: true
      preference :page_cache_ttl, :integer, default: 10.minutes.to_i

      preference :products_per_page, :integer, default: 20

      preference :search_min_query_length, :integer, default: 2
    end
  end
end
