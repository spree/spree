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

        content_tag(:div, info_row + menu_container,
                    class: 'menu-item menu-container-item dragable removable-dom-element',
                    data: { item_id: item.id })
      end

      def default_menu_for_store?(menu)
        menu.store.default_locale == menu.locale
      end
    end
  end
end
