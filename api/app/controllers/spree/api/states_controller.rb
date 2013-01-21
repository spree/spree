module Spree
  module Api
    class StatesController < Spree::Api::BaseController

      def index
        scope = if params[:country_id]
          State.where(:country_id => params[:country_id])
        else
          State.scoped
        end

        @states = scope.ransack(params[:q]).result.
                     includes(:country).order('name ASC').
                     page(params[:page]).per(params[:per_page])

        respond_with(@states)
      end

      def show
        @state = State.find(params[:id])
        respond_with(@state)
      end
    end
  end
end
