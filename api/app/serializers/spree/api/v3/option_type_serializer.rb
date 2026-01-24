module Spree
  module Api
    module V3
      class OptionTypeSerializer < BaseSerializer
        typelize_from Spree::OptionType

        attributes :id, :name, :presentation, :position
      end
    end
  end
end
