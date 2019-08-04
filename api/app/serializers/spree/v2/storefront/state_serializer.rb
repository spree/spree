module Spree
  module V2
    module Storefront
      class StateSerializer < BaseSerializer
        set_type :state

        attributes :id, :abbr, :name
      end
    end
  end
end
