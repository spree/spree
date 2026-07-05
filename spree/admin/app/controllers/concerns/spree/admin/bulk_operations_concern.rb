module Spree
  module Admin
    module BulkOperationsConcern
      extend ActiveSupport::Concern

      def bulk_add_tags
        Spree::Tags::BulkAdd.call(tag_names: params[:tags], records: bulk_collection)
        after_bulk_tags_change

        handle_bulk_operation_response
      end

      def bulk_remove_tags
        Spree::Tags::BulkRemove.call(tag_names: params[:tags], records: bulk_collection)
        after_bulk_tags_change

        handle_bulk_operation_response
      end

      private

      # Hook for subclasses to perform additional actions after bulk tag operations
      def after_bulk_tags_change
        # Override in controller to add custom behavior
      end

      def handle_bulk_operation_response
        redirect_back fallback_location: request.referer, status: :see_other
      end

      def bulk_collection
        @bulk_collection ||= model_class.accessible_by(current_ability, :update).where(id: params[:ids])
      end
    end
  end
end
