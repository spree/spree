module Spree
  module Api
    module V3
      class StateSerializer < BaseSerializer
        attributes :id, :name, :abbr, :country_id
      end
    end
  end
end
