require 'digest'

module Spree
  module NavigationHelper
    def spree_navigation_data
      ActiveSupport::Deprecation.warn(<<-DEPRECATION, caller)
        NavigationHelper#spree_navigation_data is deprecated and will be removed in Spree 5.0.
        Please migrate to the new navigation cms system.
      DEPRECATION

      @spree_navigation_data ||= SpreeStorefrontConfig.dig(I18n.locale,
                                                           :navigation) || SpreeStorefrontConfig.dig(current_store.code,
                                                                                                     :navigation) || SpreeStorefrontConfig.dig(
                                                                                                       :default, :navigation
                                                                                                     ) || []
    # safeguard for older Spree installs that don't have spree_navigation initializer
    # or spree.yml file present
    rescue StandardError
      []
    end

    def spree_nav_cache_key(section = 'header')
      @spree_nav_cache_key = begin
        keys = base_cache_key + [current_store, spree_navigation_data_cache_key, Spree::Config[:logo], stores&.cache_key, section]
        Digest::MD5.hexdigest(keys.join('-'))
      end
    end

    def main_nav_image(image_path, title = '')
      image_url = asset_path(asset_exists?(image_path) ? image_path : 'noimage/plp.png')

      lazy_image(
        src: image_url,
        alt: title,
        width: 350,
        height: 234
      )
    end

    def should_render_internationalization_dropdown?
      (defined?(should_render_locale_dropdown?) && should_render_locale_dropdown?) ||
        (defined?(should_render_currency_dropdown?) && should_render_currency_dropdown?)
    end

    def spree_localized_item_link(item)
      return if item.destination.nil?

      output_locale = if locale_param
                        "/#{locale}"
                      end

      if Spree::MenuItem::DYNAMIC_RESOURCE_TYPE.include? item.linked_resource_type
        output_locale.to_s + item.destination
      elsif item.linked_resource_type == 'Home Page'
        "/#{locale_param}"
      else
        item.destination
      end
    end

    private

    def spree_navigation_data_cache_key
      @spree_navigation_data_cache_key ||= Digest::MD5.hexdigest(spree_navigation_data.to_s)
    end
  end
end
