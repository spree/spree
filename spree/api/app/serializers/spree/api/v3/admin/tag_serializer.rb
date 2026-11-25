module Spree
  module Api
    module V3
      module Admin
        # A tag by name: tags have no identity of their own in the API.
        class TagSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize name: :string

          attributes :name
        end
      end
    end
  end
end
