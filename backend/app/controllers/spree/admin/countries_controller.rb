module Spree
  module Admin
    class CountriesController < ResourceController
      private

        def collection
          super.order(:name)
        end
    end
  end
end
