module Spree
  module Api
    module V3
      class StateSerializer
        include Alba::Resource
        include Typelizer::DSL

        typelize abbr: :string, name: :string

        attributes :abbr, :name
      end
    end
  end
end
