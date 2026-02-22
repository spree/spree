module Spree
  module Api
    module V3
      class CurrencySerializer
        include Alba::Resource
        include Typelizer::DSL

        typelize iso_code: :string, name: :string, symbol: :string

        attributes :iso_code, :name, :symbol
      end
    end
  end
end
