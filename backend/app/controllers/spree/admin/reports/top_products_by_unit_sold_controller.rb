module Spree
  module Admin
    module Reports
      class TopProductsByUnitSoldController < Spree::Admin::BaseController
        def show
          respond_to do |format|
            format.html
            format.json do
              serializer = Spree::Admin::Reports::TopProductsByUnitSold::JsonSerializer.new
              render json: serializer.call(filtered_data)
            end
            format.csv do
              send_data Spree::Admin::Reports::TopProductsByUnitSold::CsvSerializer.new.call(filtered_data), filename: 'top_products_by_unit.csv', disposition: 'attachment'
            end
          end
        end

        private

        def filtered_data
          Spree::Admin::Reports::Orders::TopProductsByUnitSold.new(params).call
        end
      end
    end
  end
end
