module Spree
  class FrontendConfiguration < Preferences::Configuration
    preference :coupon_codes_enabled, :boolean, default: true # Determines if we show coupon code form at cart and checkout
    preference :locale, :string, default: Rails.application.config.i18n.default_locale
    preference :products_filters, :array, default: %w(keywords price sort_by)
    preference :remember_me_enabled, :boolean, default: true
  end
end
