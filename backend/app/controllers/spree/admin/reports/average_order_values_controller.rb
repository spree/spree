module Spree
  module Admin
    module Reports
      class AverageOrderValuesController < Spree::Admin::BaseController
        def show
          objects = Spree::Admin::Reports::AverageOrderValuesQuery.new.call(params)

          respond_to do |format|
            format.html
            format.json do
              serializer = Spree::Admin::Reports::AverageOrderValues::JsonSerializer.new
              render json: serializer.call(objects)
            end
          end
        end
      end
    end
  end
end
