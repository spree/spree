module Spree
  module Api
    class StatesController < Spree::Api::BaseController
      skip_before_filter :check_for_user_or_api_key
      skip_before_filter :authenticate_user

      def index
        @states = scope.ransack(params[:q]).result.
                    includes(:country).order('name ASC')

        if params[:page] || params[:per_page]
          @states = @states.page(params[:page]).per(params[:per_page])
        end

        respond_with(@states)
      end

      def show
        @state = scope.find(params[:id])
        respond_with(@state)
      end

      private
        def scope
          if params[:country_id]
            @country = Country.find(params[:country_id])
            return @country.states
          else
            return State.scoped
          end
        end
    end
  end
end
