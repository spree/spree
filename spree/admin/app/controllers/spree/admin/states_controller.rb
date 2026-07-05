module Spree
  module Admin
    class StatesController < ResourceController
      belongs_to 'spree/country', find_by: :id

      def select_options
        states = @country.states.accessible_by(current_ability).order(:name)

        render json: states.to_tom_select_json
      end
    end
  end
end
