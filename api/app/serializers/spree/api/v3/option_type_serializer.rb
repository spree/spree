module Spree
  module Api
    module V3
      class OptionTypeSerializer < BaseSerializer
        typelize name: :string, presentation: :string, position: :number

        attributes :name, :presentation, :position
      end
    end
  end
end
