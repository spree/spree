module Spree
  module Api
    module V3
      module Admin
        # How many products a request removed. Products that were not members are not counted.
        class RemovedCountSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize removed_count: :number

          attributes :removed_count
        end
      end
    end
  end
end
