module Spree
  module Admin
    class StatesController < Spree::Admin::BaseController
      def select_options
        states = Spree::State.accessible_by(current_ability)
        states = states.where(country_id: params[:country_id]) if params[:country_id].present?
        states = states.order(:name)

        render json: states.pluck(:id, :name).map { |id, name| { id: id, name: name } }
      end
    end
  end
end
