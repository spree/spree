module Spree
  module Admin
    class InventorySettingsController < Spree::Admin::BaseController

      def update
        Spree::Config.set(params[:preferences])
        flash[:notice] = I18n.t(:inventory_settings_updated)

        redirect_to edit_admin_inventory_settings_path
      end
    end
  end

end
