module Spree
  module Api
    module V3
      module Admin
        # How many products a request added. Products that were members already are not counted.
        class AddedCountSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize added_count: :number

          attributes :added_count
        end
      end
    end
  end
end
