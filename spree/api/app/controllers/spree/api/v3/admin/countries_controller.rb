module Spree
  module Api
    module V3
      module Admin
        class CountriesController < ResourceController
          # Public reference data (the storefront serves the same list) — exempt
          # from the key gate like `/tags`, so address forms work for any staff
          # member or key. CanCanCan still applies for JWT principals via the
          # staff baseline's Country read grant.
          skip_scope_check!

          # Override base index to skip pagination — there are ~250 countries
          # and address-form dropdowns need them all at once. Pagy's global
          # max_limit (100) prevents using the paginated path for this.
          #
          # Countries are reference data rather than records, so this reads
          # from the registry and needs no authorization beyond the admin
          # credential the base controller already checked: the list is the
          # same for every store and carries nothing store-specific.
          def index
            @collection = scope
            render json: { data: serialize_collection(@collection), meta: { count: @collection.size } }
          end

          protected

          def model_class
            Spree::Country
          end

          def serializer_class
            Spree.api.admin_country_serializer
          end

          def scope
            Spree::Country.all.sort_by(&:name)
          end

          def find_resource
            Spree::Country.find_by_iso!(params[:id])
          end
        end
      end
    end
  end
end
