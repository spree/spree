module Spree
  module Api
    module V3
      module Store
        class OptionTypeSerializer < BaseSerializer
          attributes :id, :name, :presentation, :position
        end
      end
    end
  end
end
