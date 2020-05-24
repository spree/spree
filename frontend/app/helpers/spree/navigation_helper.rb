require 'digest'

module Spree
  module NavigationHelper
    def spree_navigation_data
      SpreeStorefrontConfig.dig(current_store.code, :navigation) || SpreeStorefrontConfig.dig(:default, :navigation) || []
    # safeguard for older Spree installs that don't have spree_navigation initializer
    # or spree.yml file present
    rescue
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

    private

    def spree_navigation_data_cache_key
      @spree_navigation_data_cache_key ||= Digest::MD5.hexdigest(spree_navigation_data.to_s)
    end
  end
end
