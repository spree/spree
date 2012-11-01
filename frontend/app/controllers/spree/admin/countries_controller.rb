module Spree
  module Admin
    class CountriesController < ResourceController

        def collection
          super.order(:name)
        end

    end
  end
end
