module Spree
  module Admin
    class StockTransfersController < ResourceController
      before_action :prepare_params, only: :create

      include ProductsBreadcrumbConcern

      create.fails :load_variant_omit_ids

      before_action :add_breadcrumbs

      private

      def location_after_save
        spree.admin_stock_transfer_path(@object)
      end

      def permitted_resource_params
        params.require(:stock_transfer).permit(permitted_stock_transfer_attributes)
      end

      def prepare_params
        stock_movements_attributes = params.dig(:stock_transfer, :stock_movements_attributes) || []
        stock_movements_attributes.each do |_key, sm_params|
          if sm_params[:stock_item_id].blank? && sm_params[:location_id].present?
            sm_params[:stock_item_id] = Spree::StockLocation.
                                        accessible_by(current_ability).
                                        find(sm_params[:location_id]).
                                        stock_item_or_create(sm_params[:variant_id]).id
          end

          sm_params.delete(:variant_id)
        end
      end

      def load_variant_omit_ids
        @variant_omit_ids = @stock_transfer.stock_movements.map(&:variant_id)
      end

      def add_breadcrumbs
        add_breadcrumb Spree.t(:stock), spree.admin_stock_items_path
        add_breadcrumb Spree.t(:stock_transfers), spree.admin_stock_transfers_path

        if @stock_transfer.present? && @stock_transfer.persisted?
          add_breadcrumb @stock_transfer.number, spree.admin_stock_transfer_path(@stock_transfer)
        end
      end
    end
  end
end
