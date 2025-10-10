module Spree
  module Api
    module V2
      module Platform
        class CalculatorSerializer < BaseSerializer
          include ResourceSerializerConcern

          attributes :type

          attribute :preferences do |calculator|
            calculator.preferences
          end
        end
      end
    end
  end
end
