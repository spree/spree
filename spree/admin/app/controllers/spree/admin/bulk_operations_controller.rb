module Spree
  module Admin
    class BulkOperationsController < Spree::Admin::BaseController
      BULK_ACTION_PERMISSIONS = {
        set_active: [:bulk_set_active, Spree::Product],
        set_draft: [:bulk_set_draft, Spree::Product],
        set_archived: [:bulk_set_archived, Spree::Product],
        add_to_taxons: [:manage, Spree::Classification],
        remove_from_taxons: [:manage, Spree::Classification],
        add_tags: [:manage_tags, Spree::Product],
        remove_tags: [:manage_tags, Spree::Product]
      }.freeze

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

      def authorize_admin
        permission = BULK_ACTION_PERMISSIONS[params[:kind]&.to_sym]
        permission.present? ? authorize!(*permission) : super
      end
    end
  end
end
