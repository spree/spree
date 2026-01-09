module Spree
  module Admin
    module BulkOperationsConcern
      extend ActiveSupport::Concern

      # GET /admin/:resources/bulk_modal?kind=:action_key
      # Generic bulk modal action that reads configuration from BulkAction
      def bulk_modal
        @bulk_action = find_bulk_action(params[:kind])

        if @bulk_action.nil?
          head :not_found
          return
        end

        @title = @bulk_action.resolve_title
        @body = @bulk_action.resolve_body
        @form_partial = @bulk_action.form_partial
        @form_partial_locals = @bulk_action.form_partial_locals || {}

        render partial: 'spree/admin/shared/bulk_modal_content'
      end

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

      def find_bulk_action(key)
        return nil if key.blank?

        table_key = controller_name.to_sym
        table = Spree.admin.tables.get(table_key)
        return nil if table.nil?

        table.find_bulk_action(key.to_sym)
      end
    end
  end
end
