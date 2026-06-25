module Spree
  module Admin
    class CountriesController < Spree::Admin::BaseController
      RESULT_LIMIT = 50

      def select_options
        q = params[:q]

        countries =
          if q.is_a?(String)
            search_countries(q)
          else
            Spree::Country.accessible_by(current_ability).ransack(q).result.order(:name).limit(RESULT_LIMIT)
          end

        render json: countries.map { |country| { id: country.id, name: Spree::LocalizedNames.country_option_label(country) } }
      end

      private

      # Matches the localized name shown to the admin (what they type), as well
      # as the stored English name and ISO code, so search works in any admin UI
      # locale — not only when the visible label happens to be English.
      def search_countries(query)
        scope = Spree::Country.accessible_by(current_ability)
        query = query.to_s.strip
        return scope.order(:name).limit(RESULT_LIMIT) if query.blank?

        downcased = query.downcase
        scope.to_a.
          select { |country| country_matches?(country, downcased) }.
          sort_by { |country| Spree::LocalizedNames.country_name(country.iso, fallback: country.name) }.
          first(RESULT_LIMIT)
      end

      def country_matches?(country, query)
        Spree::LocalizedNames.country_name(country.iso, fallback: country.name).downcase.include?(query) ||
          country.name.to_s.downcase.include?(query) ||
          country.iso.to_s.downcase.include?(query)
      end
    end
  end
end
