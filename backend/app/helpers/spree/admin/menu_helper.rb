module Spree
  module Admin
    module MenuHelper
      def build_menu_item(menu, item)
        menu_item_that_accepts_nested_items(menu, item)
      end

      def menu_item_bar(menu, item)
        edit_button = link_to_edit(item, no_text: true, url: spree.edit_admin_menu_menu_item_path(menu, item))
        delete_button = link_to_delete(item, no_text: true, url: spree.admin_menu_menu_item_path(menu, item)) if can?(:destroy, item)

        menu_item_type = content_tag(:small, item.item_type, class: 'form-text text-muted mt-0')

        image = if item.image_asset.attached? && item.image_asset.image?
                  content_tag(:div, content_tag(:div, (image_tag main_app.url_for(item.image_asset)), class: 'menu_items_image_holder'), class: 'ml-2')
                else
                  ''
                end

        description_sub_area = content_tag(:div, content_tag(:div, item.name) + content_tag(:div, menu_item_type))

        move_handle = content_tag(:div, svg_icon(name: 'sort.svg', width: '20', height: '20'), class: 'move-handle d-flex align-items-center p-3')
        description_area = content_tag(:div, description_sub_area + image, class: 'd-flex align-items-center w-100 truncate')
        buttons_area = content_tag(:div, edit_button + delete_button, class: 'd-flex align-items-center space-buttons px-2')

        content_tag(:div, move_handle + description_area + buttons_area,
                    class: 'container-item-row d-flex flex-nowrap',
                    data: { item_id: item.id, parent_id: item.parent_id })
      end

      def menu_item_that_accepts_nested_items(menu, item)
        decendents = []

        unless item.leaf?
          item.children.each do |x|
            decendents << build_menu_item(menu, x) unless item.leaf?
          end
        end

        info_row = menu_item_bar(menu, item)
        sub_menu_container = content_tag(:div, raw(decendents.join), class: 'menu-container', data: { parent_id: item.id })

        content_tag(:div, info_row + sub_menu_container, class: 'menu-item menu-container-item dragable', data: { item_id: item.id })
      end
    end
  end
end
