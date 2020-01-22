module Spree
  module NavigationHelper
    def spree_navigation_data
      SpreeStorefrontConfig.dig(current_store.code, :navigation) || SpreeStorefrontConfig.dig(:default, :navigation) || []
    # safeguard for older Spree installs that don't have spree_navigation initializer
    # or spree.yml file present
    rescue
      []
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
  end
end
