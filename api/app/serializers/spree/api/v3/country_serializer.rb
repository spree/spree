module Spree
  module Api
    module V3
      class CountrySerializer < BaseSerializer
        def attributes
          {
            id: resource.id,
            iso: resource.iso,
            iso3: resource.iso3,
            iso_name: resource.iso_name,
            name: resource.name,
            states_required: resource.states_required,
            zipcode_required: resource.zipcode_required
          }

          # Conditionally include states
          base_attrs[:states] = serialize_states if include?('states')

          base_attrs
        end

        private

        def serialize_states
          resource.states.map do |state|
            state_serializer.new(state, nested_context('states')).as_json
          end
        end

        # Serializer dependencies
        def state_serializer
          Spree::Api::Dependencies.v3_storefront_state_serializer.constantize
        end
      end
    end
  end
end
