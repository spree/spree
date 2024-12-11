module Spree
  module Admin
    class StockTransfersController < ResourceController
      before_action :prepare_params, only: :create

      private

      def location_after_save
        spree.admin_stock_transfer_path(@object)
      end

      def collection
        params[:q] ||= {}
        params[:q][:s] ||= 'created_at desc'

        @search = super.accessible_by(current_ability, :index).ransack(params[:q])
        @stock_transfers = @search.result.
                           page(params[:page]).
                           per(params[:per_page])
      end

      def permitted_resource_params
        params.require(:stock_transfer).permit(:source_location_id, :destination_location_id, :reference,
                                               stock_movements_attributes: [:variant_id, :quantity, :originator_id, :stock_item_id])
      end

      def prepare_params
        if params.dig(:stock_transfer, :stock_movements_attributes).blank?
          flash[:error] = Spree.t('stock_transfer.errors.must_have_variant')
          render :new, status: :unprocessable_entity
          return
        end

        params.dig(:stock_transfer, :stock_movements_attributes).each do |_key, sm_params|
          if sm_params[:stock_item_id].blank? && sm_params[:originator_id].present?
            sm_params[:stock_item_id] =
              Spree::StockLocation.accessible_by(current_ability).find(sm_params[:originator_id]).stock_item_or_create(sm_params[:variant_id]).id
          end

          sm_params.delete(:variant_id)
        end
      end
    end
  end
end
