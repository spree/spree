module Spree
  module Api
    module V3
      class StateSerializer < BaseSerializer
        typelize name: :string, abbr: :string, country_id: :string

        attribute :country_id do |state|
          state.country&.prefix_id
        end

        attributes :name, :abbr
      end
    end
  end
end
