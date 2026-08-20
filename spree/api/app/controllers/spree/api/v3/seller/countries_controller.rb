module Spree
  module Api
    module V3
      module Seller
        # Countries for the panel's address forms.
        #
        # Public reference data — the same list the storefront and the
        # operator's dashboard serve — so it is exempt from the key gate, as
        # its admin twin is. A seller filling in a billing address needs every
        # country, not the ones their marketplace happens to sell into.
        class CountriesController < Seller::BaseController
          skip_scope_check!

          # GET /api/v3/seller/countries
          #
          # Unpaginated: there are ~250 countries and an address dropdown needs
          # them all at once, which Pagy's global max_limit would prevent.
          def index
            countries = Spree::Country.all.sort_by(&:name)

            render json: {
              data: countries.map { |country| serialize_country(country) },
              meta: { count: countries.size }
            }
          end

          private

          def serialize_country(country)
            Spree.api.country_serializer.new(
              country, params: { store: current_store, expand: ['states'] }
            ).to_h
          end
        end
      end
    end
  end
end
