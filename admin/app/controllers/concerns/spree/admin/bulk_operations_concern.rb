module Spree
  module Admin
    module BulkOperationsConcern
      extend ActiveSupport::Concern

      def bulk_add_tags
        Spree::Tags::BulkAdd.call(tag_names: params[:tags], records: bulk_collection)

        handle_bulk_operation_response
      end

      def bulk_remove_tags
        Spree::Tags::BulkRemove.call(tag_names: params[:tags], records: bulk_collection)

        handle_bulk_operation_response
      end

      private

      def handle_bulk_operation_response
        respond_to do |format|
          format.turbo_stream do
            flash.now[:success] = flash_message_for(bulk_collection, :successfully_updated)
            render partial: 'spree/admin/shared/close_bulk_modal'
          end
          format.html do
            flash[:success] = flash_message_for(bulk_collection, :successfully_updated)
            redirect_to request.referer
          end
        end
      end

      def bulk_collection
        @bulk_collection ||= model_class.accessible_by(current_ability, :update).where(id: params[:ids])
      end
    end
  end
end
