module Spree
  module Admin
    module Reports
      class TotalSalesController < Spree::Admin::BaseController
        def show
          respond_to do |format|
            format.html
            format.json do
              render json: Spree::Admin::Reports::TotalSales::JsonSerializer.new.call(filtered_data)
            end
            format.csv do
              send_data Spree::Admin::Reports::TotalSales::CsvSerializer.new.call(filtered_data), filename: 'total_sales.csv', disposition: 'attachment'
            end
          end
        end

        private

        def filtered_data
          Spree::Admin::Reports::Orders::TotalSales.new(params).call
        end
      end
    end
  end
end
