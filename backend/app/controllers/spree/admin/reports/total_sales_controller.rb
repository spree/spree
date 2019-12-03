module Spree
  module Admin
    module Reports
      class TotalSalesController < Spree::Admin::BaseController
        def show
          objects = Spree::Admin::Reports::Orders::TotalSales.new(params).call

          respond_to do |format|
            format.html
            format.json do
              render json: Spree::Admin::Reports::TotalSales::JsonSerializer.new.call(objects)
            end
            format.csv do
              render plain: Spree::Admin::Reports::TotalSales::CsvSerializer.new.call(objects)
            end
          end
        end
      end
    end
  end
end
