module Spree
  module Admin
    class SearchController < BaseController
      def option_values
        query = params[:q]&.strip

        if query.present?
          json = Spree::OptionValue.includes(:option_type).search_by_name(query).map do |ov|
            {
              id: ov.id,
              name: ov.display_presentation
            }
          end

          render json: json
        else
          render json: []
        end
      end
    end
  end
end
