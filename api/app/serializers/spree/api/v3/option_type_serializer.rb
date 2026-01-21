module Spree
  module Api
    module V3
      class OptionTypeSerializer < BaseSerializer
        attributes :id, :name, :presentation, :position
      end
    end
  end
end
