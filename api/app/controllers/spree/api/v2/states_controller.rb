module Spree
  module Api
    module V2
      class StatesController < Spree::Api::BaseController
        skip_before_action :set_expiry
        skip_before_action :check_for_user_or_api_key
        skip_before_action :authenticate_user

        def index
          @states = scope.ransack(params[:q]).result.
                    includes(:country).order('name ASC')

          if params[:page] || params[:per_page]
            @states = @states.page(params[:page]).per(params[:per_page])
          end

          state = @states.last
          if stale?(state)
            render json: @states, meta: {
              count: @states.count,
              current_page: params[:page] ? params[:page].to_i : 1,
              per_page: params[:per_page] || Kaminari.config.default_per_page,
            }
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
end
