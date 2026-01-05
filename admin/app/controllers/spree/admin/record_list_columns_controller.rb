module Spree
  module Admin
    class RecordListColumnsController < Spree::Admin::BaseController
      # POST /admin/record_list_columns
      # Updates the selected columns for a record list in the session
      def update
        list_key = params[:list_key]
        columns = params[:columns]

        if list_key.present?
          if columns.present?
            # Filter to only include valid column keys
            column_keys = Array(columns).map(&:to_sym)
            session["record_list_columns_#{list_key}"] = column_keys.join(',')
          else
            # Clear selection to use defaults
            session.delete("record_list_columns_#{list_key}")
          end
        end

        redirect_url = params[:redirect_url].presence || request.referer || spree.admin_path
        redirect_to redirect_url, status: :see_other
      end
    end
  end
end
