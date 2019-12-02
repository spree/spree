module Spree
  module Admin
    module Reports
      class TotalSalesController < Spree::Admin::BaseController
        def show
          orders = Spree::Admin::Reports::TotalSalesQuery.new.call(params)

          respond_to do |format|
            format.html
            format.json do
              render json: Spree::Admin::Reports::TotalSales::JsonSerializer.new.call(orders)
            end
            format.csv do
              render plain: Spree::Admin::Reports::TotalSales::CsvSerializer.new.call(orders)
            end
          end
        end
      end
    end
  end
end
