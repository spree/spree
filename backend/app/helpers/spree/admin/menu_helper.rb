module Spree
  module Admin
    module MenuHelper
      def build_menu_item(menu, item)
        menu_item_that_accepts_nested_items(menu, item)
      end

      def menu_item_bar(menu, item)
        edit_button = link_to_edit(item, no_text: true, url: spree.edit_admin_menu_menu_item_path(menu, item))
        delete_button = link_to_delete(item, no_text: true, url: spree.admin_menu_menu_item_path(menu, item)) if can?(:destroy, item)

        move_handle = content_tag(:div, svg_icon(name: 'sort.svg', width: '20', height: '20'), class: 'move-handle d-flex align-items-center p-3')
        description_area = content_tag(:div, item.name, class: 'd-flex align-items-center w-100')
        buttons_area = content_tag(:div, edit_button + delete_button, class: 'd-flex align-items-center space-buttons px-2')

        content_tag(:div, move_handle + description_area + buttons_area,
                    class: 'container-item-row d-flex flex-nowrap',
                    data: { item_id: item.id, parent_id: item.parent_id })
      end

      def menu_item_that_accepts_nested_items(menu, item)
        decendents = build_menu_item(menu, item.children[0]) unless item.leaf?

        info_row = menu_item_bar(menu, item)
        sub_menu_container = content_tag(:div, decendents, class: 'menu-container', data: { parent_id: item.id })

        content_tag(:div, info_row + sub_menu_container, class: 'menu-item menu-container-item dragable', data: { item_id: item.id })
      end
    end
  end
end
