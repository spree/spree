module Spree
  module Api
    module V1
      class CountriesController < Spree::Api::BaseController
        skip_before_action :authenticate_user

        def index
          @countries = Country.accessible_by(current_ability, :read).ransack(params[:q]).result.
                       order('name ASC').
                       page(params[:page]).per(params[:per_page])
          country = Country.order('updated_at ASC').last
          respond_with(@countries) if stale?(country)
        end

        def show
          @country = Country.accessible_by(current_ability, :read).find(params[:id])
          respond_with(@country)
        end
      end
    end
  end
end
