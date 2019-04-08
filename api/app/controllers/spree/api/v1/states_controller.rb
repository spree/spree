module Spree
  module Api
    module V1
      class StatesController < Spree::Api::BaseController
        skip_before_action :authenticate_user

        def index
          @states = scope.ransack(params[:q]).result.includes(:country)

          if params[:page] || params[:per_page]
            @states = @states.page(params[:page]).per(params[:per_page])
          end

          state = @states.last
          respond_with(@states) if stale?(state)
        end

        def show
          @state = scope.find(params[:id])
          respond_with(@state)
        end

        private

        def scope
          if params[:country_id]
            @country = Country.accessible_by(current_ability, :show).find(params[:country_id])
            @country.states.accessible_by(current_ability).order('name ASC')
          else
            State.accessible_by(current_ability).order('name ASC')
          end
        end
      end
    end
  end
end
