module Spree
  module Api
    class StatesController < Spree::Api::BaseController

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
            @country = Country.accessible_by(current_ability, :read).find(params[:country_id])
            return @country.states.accessible_by(current_ability, :read)
          else
            return State.accessible_by(current_ability, :read)
          end
        end
    end
  end
end
