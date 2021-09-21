module Spree
  class FrontendConfiguration < Preferences::Configuration
    preference :additional_filters_partials, :array, default: %w()
    preference :always_put_site_name_in_title, :boolean, default: true
    preference :coupon_codes_enabled, :boolean, default: true # Determines if we show coupon code form at cart and checkout
    preference :http_cache_enabled, :boolean, default: true
    preference :layout, :string, default: 'spree/layouts/spree_application'
    preference :locale, :string, default: nil
    preference :products_filters, :array, default: %w(keywords price sort_by)
    preference :remember_me_enabled, :boolean, default: true
    preference :shipping_instructions, :boolean, default: false # Request instructions/info for shipping
    preference :show_raw_product_description, :boolean, default: false
    preference :show_store_selector, :boolean, default: false
    preference :title_site_name_separator, :string, default: '-' # When always_put_site_name_in_title is true, insert a separator character before the site name in the title
  end
end
