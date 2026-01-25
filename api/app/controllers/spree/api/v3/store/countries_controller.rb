module Spree
  module Api
    module V3
      module Store
        class CountriesController < Store::BaseController
          # GET /api/v3/store/countries
          # Returns all countries available for checkout from store's checkout zone
          def index
            countries = checkout_countries.order(:name)

            render json: {
              data: countries.map { |country| serialize_country(country) }
            }
          end

          # GET /api/v3/store/countries/:id
          # Returns a single country with its states
          def show
            country = checkout_countries.find_by!(iso: params[:id].upcase)

            render json: serialize_country(country, include_states: true)
          end

          private

          # Get countries from the store's checkout zone
          # Falls back to all countries if no checkout zone is configured
          def checkout_countries
            zone = current_store.checkout_zone
            return Spree::Country.all unless zone

            zone.country_list
          end

          def serialize_country(country, include_states: false)
            data = {
              iso: country.iso,
              iso3: country.iso3,
              name: country.name,
              states_required: country.states_required,
              zipcode_required: country.zipcode_required
            }

            if include_states
              data[:states] = country.states.order(:name).map do |state|
                { abbr: state.abbr, name: state.name }
              end
            end

            data
          end
        end
      end
    end
  end
end
