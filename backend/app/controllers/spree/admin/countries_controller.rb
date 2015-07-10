module Spree
  module Admin
    class CountriesController < ResourceController

        def collection
          super.order(:name)
        end

        def zones
          render json: @object.zones.to_json
        end

    end
  end
end
