module Spree
  module Admin
    module MenuHelper
      def menu_item_bar(menu, item)
        render 'spree/admin/menus/nested_menu_items/item_bar', menu: menu, item: item
      end

      def build_menu_item(menu, item)
        decendents = []

        unless item.leaf?
          item.children.each do |child_item|
            decendents << build_menu_item(menu, child_item) unless item.leaf?
          end
        end

        info_row = menu_item_bar(menu, item)
        menu_container = content_tag(:div, raw(decendents.join), class: 'menu-container', data: { parent_id: item.id })

        content_tag(:div, info_row + menu_container, class: 'menu-item menu-container-item dragable removable-dom-element', data: { item_id: item.id })
      end

      def resorce_types_dropdown_values
        formatted_resouces = []

        Spree::MenuItem::LINKED_RESOURCE_TYPE.each do |resource_type|
          formatted = if Spree::MenuItem::DYNAMIC_RESOURCE_TYPE.include? resource_type
                        str = resource_type.split('::', 10).last
                        if str.starts_with?('Cms')
                          str.slice(3, 100)
                        else
                          str
                        end
                      else
                        resource_type
                      end

          formatted_resouces << [formatted, resource_type]
        end

        formatted_resouces
      end

      def menu_locations_dropdown_values
        menu_items_for_select = []

        Spree::Menu::MENU_LOCATIONS.each do |location|
          parameterized_location = location.parameterize(separator: '_')

          menu_items_for_select << [location, parameterized_location]
        end

        menu_items_for_select
      end

      def default_menu_for_store?(menu)
        menu.store.default_locale == menu.locale
      end

      def to_path_format(string)
        string.parameterize(separator: '_')
      end
    end
  end
end
