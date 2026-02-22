module Spree
  module Api
    module V3
      class LocaleSerializer
        include Alba::Resource
        include Typelizer::DSL

        typelize code: :string, name: :string

        attributes :code, :name
      end
    end
  end
end
