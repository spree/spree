module Spree
  module Admin
    class MenuItemsController < ResourceController
      belongs_to 'spree/menu'

      def collection_url
        spree.edit_admin_menu_path(@menu)
      end

      def location_after_save
        spree.edit_admin_menu_menu_item_path(@menu, @menu_item)
      end

      def remove_icon
        if @menu_item.icon&.destroy
          flash[:success] = Spree.t('notice_messages.icon_removed')
          redirect_to spree.edit_admin_menu_menu_item_path(@menu, @menu_item)
        else
          flash[:error] = Spree.t('errors.messages.cannot_remove_icon')
          render :edit
        end
      end
    end
  end
end
