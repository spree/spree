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
            data = Spree.api.country_serializer.new(country, params: { includes: [] }).to_h

            if include_states
              data[:states] = serialize_collection(country.states.order(:name), Spree.api.state_serializer)
            end

            data
          end

          def serialize_collection(collection, serializer_class)
            collection.map { |item| serializer_class.new(item).to_h }
          end
        end
      end
    end
  end
end
