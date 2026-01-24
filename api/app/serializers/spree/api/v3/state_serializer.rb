module Spree
  module Api
    module V3
      class StateSerializer < BaseSerializer
        typelize_from Spree::State

        attributes :id, :name, :abbr, :country_id
      end
    end
  end
end
