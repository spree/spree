module Spree
  module Admin
    module TablesHelper

      # Adds class 'active' to <th> & <td> tags
      # for better tables styling
      def sort_by_active_class(row)
        if params[:q][:s] && params[:q][:s].include?(row)
          return "sort-active"
        end
      end

    end
  end
end
