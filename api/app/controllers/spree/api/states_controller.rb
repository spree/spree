module Spree
  module Api
    class StatesController < Spree::Api::BaseController
      skip_before_filter :set_expiry
      skip_before_filter :check_for_user_or_api_key
      skip_before_filter :authenticate_user

      def index
        @states = scope.ransack(params[:q]).result.
                    includes(:country).order('name ASC')

        @states = @states.page(params[:page]).per(params[:per_page])

        state = @states.last
        if stale?(state)
          render json: @states, meta: pagination(@states)
        end
      end

      def show
        @state = scope.find(params[:id])
        render json: @state
      end

      private
        def scope
          if params[:country_id]
            @country = Country.accessible_by(current_ability, :read).find(params[:country_id])
            return @country.states.accessible_by(current_ability, :read)
          else
            return State.accessible_by(current_ability, :read)
          end
        end
    end
  end
end
