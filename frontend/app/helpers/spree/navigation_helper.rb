require 'digest'

module Spree
  module NavigationHelper
    def spree_nav_cache_key(section = 'header')
      @spree_nav_cache_key = begin
        keys = base_cache_key + [current_store, Spree::Config[:logo], stores&.cache_key, section]
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

    # Find a menu by its unique_code
    # this method will only return a menu if it is
    # available for use in the current store.
    def menu(unique_code)
      menu = available_menus.by_unique_code(unique_code)
      menu[0]
    end

    # Returns the root for the menu by unique_code.
    # You can use .children to retrieve the top level of menu items,
    # or .descendants to retrieve all menu items.
    def root_item_for_menu(unique_code)
      if menu(unique_code).present?
        menu(unique_code).root
      end
    end

    # Returns only the top level items for the menu by unique_code
    def top_level_items_for_menu(unique_code)
      if menu(unique_code).present?
        menu(unique_code).root.children
      end
    end

    # Returns all items for the menu by unique_code
    def all_items_for_menu(unique_code)
      if menu(unique_code).present?
        menu(unique_code).root.descendants
      end
    end

    private

    def spree_navigation_data_cache_key
      # TODO: Fix cache key for new menus
      # @spree_navigation_data_cache_key ||= root_item_for_menu('spree-all-main').self_and_descendants
    end
  end
end
