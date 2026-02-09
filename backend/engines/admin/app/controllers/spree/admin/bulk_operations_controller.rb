module Spree
  module Admin
    class BulkOperationsController < Spree::Admin::BaseController
      # GET /admin/bulk_operations/new?kind=:action_key&table_key=:table_key
      # Generic bulk modal action that reads configuration from BulkAction
      def new
        @table_key = params[:table_key]&.to_sym
        @bulk_action = find_bulk_action(params[:kind], @table_key)

        if @bulk_action.nil?
          head :not_found
          return
        end

        @title = @bulk_action.resolve_title
        @body = @bulk_action.resolve_body
        @form_partial = @bulk_action.form_partial
        @form_partial_locals = @bulk_action.form_partial_locals || {}
        @button_text = @bulk_action.resolve_button_text
        @button_class = @bulk_action.button_class
      end

      private

      def find_bulk_action(key, table_key)
        return nil if key.blank? || table_key.blank?
        return nil unless Spree.admin.tables.registered?(table_key)

        table = Spree.admin.tables.get(table_key)
        table.find_bulk_action(key.to_sym)
      end
    end
  end
end
