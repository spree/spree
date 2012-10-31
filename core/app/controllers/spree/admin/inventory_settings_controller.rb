module Spree
  module Admin
    class InventorySettingsController < Spree::Admin::BaseController

      def update
        Spree::Config.set(params[:preferences])
        flash[:success] = t(:successfully_updated, :resource => t(:inventory_settings))
        redirect_to edit_admin_inventory_settings_path
      end
    end
  end

end
