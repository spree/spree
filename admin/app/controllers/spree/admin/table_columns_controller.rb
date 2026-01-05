module Spree
  module Admin
    class TableColumnsController < Spree::Admin::BaseController
      # POST /admin/table_columns
      # Updates the selected columns for a table in the session
      def update
        session_key = table_session_key
        columns = params[:columns]

        if session_key.present?
          if columns.present?
            # Filter to only include valid column keys
            column_keys = Array(columns).map(&:to_sym)
            session[session_key] = column_keys.join(',')
          else
            # Clear selection to use defaults
            session.delete(session_key)
          end
        end

        # Use url_from to validate redirect URL is same-origin
        redirect_url = url_from(params[:redirect_url]) || url_from(request.referer) || spree.admin_path
        redirect_to redirect_url, status: :see_other
      end

      private

      # Returns a validated session key for table columns, or nil if invalid
      # Only allows registered table keys to prevent session manipulation
      def table_session_key
        table_key = params[:table_key].to_s.to_sym
        return nil unless Spree.admin.tables.registered?(table_key)

        "table_columns_#{table_key}"
      end
    end
  end
end
