module Spree
  module Api
    module V3
      module Store
        class StateSerializer < BaseSerializer
          attributes :id, :name, :abbr, :country_id
        end
      end
    end
  end
end
