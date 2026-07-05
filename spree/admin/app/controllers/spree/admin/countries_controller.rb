module Spree
  module Admin
    class CountriesController < Spree::Admin::BaseController
      # Returns every accessible country, sorted by its localized name. The set
      # is small and fixed, so the admin autocomplete loads the full list once
      # and filters it client-side (in the admin UI locale) rather than querying
      # the server per keystroke.
      #
      # `name` is the underlying value used for filtering (the stored English
      # country name); `label` is the localized, flag-prefixed display string.
      def select_options
        countries = Spree::Country.accessible_by(current_ability, :show).
                    sort_by(&:localized_name)

        options = countries.map do |country|
          {
            id: country.id,
            name: country.name,
            label: country.option_label
          }
        end

        render json: options
      end
    end
  end
end
