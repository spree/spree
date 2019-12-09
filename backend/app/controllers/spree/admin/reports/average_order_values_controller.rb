module Spree
  module Admin
    module Reports
      class AverageOrderValuesController < Spree::Admin::BaseController
        def show

          respond_to do |format|
            format.html
            format.json do
              serializer = Spree::Admin::Reports::AverageOrderValues::JsonSerializer.new
              render json: serializer.call(filtered_data)
            end
            format.csv do
              serializer = Spree::Admin::Reports::AverageOrderValues::CsvSerializer.new
              render plain: serializer.call(filtered_data)
            end
          end
        end

        private

        def filtered_data
          Spree::Admin::Reports::Orders::AverageOrderValues.new(params).call
        end
      end
    end
  end
end
