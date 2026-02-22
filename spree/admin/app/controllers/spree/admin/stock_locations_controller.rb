module Spree
  module Admin
    class StockLocationsController < ResourceController
      include Spree::Admin::SettingsConcern

      before_action :set_country, only: :new

      # PUT /admin/stock_locations/:id/mark_as_default
      def mark_as_default
        @stock_location.update(default: true)

        flash[:success] = flash_message_for(@stock_location, :marked_as_default)
        redirect_to spree.admin_stock_locations_path
      end

      # GET /admin/stock_locations/select_options
      def select_options
        q = params[:q]
        ransack_params = q.is_a?(String) ? { name_i_cont: q } : q
        stock_locations = Spree::StockLocation.active.accessible_by(current_ability).ransack(ransack_params).result.order(:name).limit(50)

        render json: stock_locations.map { |sl| { id: sl.id, name: sl.display_name } }
      end

      private

      def scope
        super.order_default
      end

      def set_country
        @stock_location.country = current_store.default_country
      end

      def permitted_resource_params
        params.require(:stock_location).permit(permitted_stock_location_attributes)
      end
    end
  end
end
