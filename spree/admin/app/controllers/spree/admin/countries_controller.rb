module Spree
  module Admin
    class CountriesController < Spree::Admin::BaseController
      def select_options
        q = params[:q]
        ransack_params = q.is_a?(String) ? { name_cont: q } : q
        countries = Spree::Country.accessible_by(current_ability).ransack(ransack_params).result.order(:name).limit(50)

        render json: countries.map { |country| { id: country.id, name: Spree::DisplayNames.country_option_label(country) } }
      end
    end
  end
end
