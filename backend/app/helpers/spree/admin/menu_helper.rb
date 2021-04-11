module Spree
  module Admin
    module MenuHelper
      def build_menu_item(menu, item)
        if item.container
          dragable = nil
          klazz = 'container-info-row'
          menu_item_that_accepts_nested_items(menu, item, klazz, dragable)
        else
          dragable = 'dragable'
          klazz = 'menu-item'
          standard_menu_item(menu, item, klazz, dragable)
        end
      end

      def standard_menu_item(menu, item, klazz, dragable)
        edit_button = link_to_edit(item, no_text: true, class: 'btn btn-outline-secondary btn-sm', url: spree.edit_admin_menu_menu_item_path(menu, item))
        delete_button = link_to_delete(item, no_text: true, url: spree.admin_menu_menu_item_path(menu, item)) if can?(:destroy, item)

        move_handle = content_tag(:div, svg_icon(name: 'sort.svg', width: '20', height: '20'), class: 'move-handle d-flex align-items-center p-3')
        description_area = content_tag(:div, item.name, class: 'd-flex align-items-center w-100')
        buttons_area = content_tag(:div, edit_button + delete_button, class: 'd-flex align-items-center space-buttons px-2')

        content_tag(:div, move_handle + description_area + buttons_area, class: "#{klazz} #{dragable} d-flex flex-nowrap")
      end

      def menu_item_that_accepts_nested_items(menu, item, klazz, dragable)
        info_row = standard_menu_item(menu, item, klazz, dragable)
        sub_menu_container = content_tag(:div, nil, class: 'menu-container')

        content_tag(:div, info_row + sub_menu_container, class: 'menu-container-item dragable')
      end

      # this is not used at the moment
      # Remove this if it never gets used.
      def humanize_class_name(object)
        if object.is_a? Array
          object.map do |obj|
            obj.split('::').last
          end
        elsif object.is_a? String
          object.split('::').last
        else
          'Pass me a String or an Array'
        end
      end
    end
  end
end
