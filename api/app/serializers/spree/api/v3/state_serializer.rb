module Spree
  module Api
    module V3
      class StateSerializer
        include Alba::Resource
        include Typelizer::DSL

        # ISO 3166-2 subdivision code (without country prefix)
        # No id field - iso is the identifier
        typelize iso: :string, name: :string

        attribute :iso do |state|
          state.abbr
        end

        attributes :name
      end
    end
  end
end
