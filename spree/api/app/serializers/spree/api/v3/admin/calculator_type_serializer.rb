module Spree
  module Api
    module V3
      module Admin
        # A registered calculator, with the JSON Schema of its preferences.
        class CalculatorTypeSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize type: [:string, comment: 'The value to send as the calculator `type`, e.g. flat_rate'],
                   name: :string,
                   schema: [:PreferenceSchema, comment: "JSON Schema of the calculator's `preferences`"]

          attributes :type, :name, :schema
        end
      end
    end
  end
end
