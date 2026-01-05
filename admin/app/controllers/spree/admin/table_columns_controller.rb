module Spree
  module Admin
    class TableColumnsController < Spree::Admin::BaseController
      # POST /admin/table_columns
      # Updates the selected columns for a table in the session
      def update
        table_key = params[:table_key]
        columns = params[:columns]

        if table_key.present?
          if columns.present?
            # Filter to only include valid column keys
            column_keys = Array(columns).map(&:to_sym)
            session["table_columns_#{table_key}"] = column_keys.join(',')
          else
            # Clear selection to use defaults
            session.delete("table_columns_#{table_key}")
          end
        end

        redirect_url = params[:redirect_url].presence || request.referer || spree.admin_path
        redirect_to redirect_url, status: :see_other
      end
    end
  end
end
