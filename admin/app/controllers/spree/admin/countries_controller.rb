module Spree
  module Admin
    class CountriesController < Spree::Admin::BaseController
      def select_options
        q = params[:q]
        ransack_params = q.is_a?(String) ? { name_cont: q } : q
        countries = Spree::Country.ransack(ransack_params).result.order(:name).limit(50)

        render json: countries.pluck(:id, :name).map { |id, name| { id: id, name: name } }
      end
    end
  end
end
