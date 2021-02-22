module Spree
  class FrontendConfiguration < Preferences::Configuration
    preference :coupon_codes_enabled, :boolean, default: true # Determines if we show coupon code form at cart and checkout
    preference :http_cache_enabled, :boolean, default: true
    preference :locale, :string, default: nil
    preference :products_filters, :array, default: %w(keywords price sort_by)
    preference :additional_filters_partials, :array, default: %w()
    preference :remember_me_enabled, :boolean, default: true
  end
end
