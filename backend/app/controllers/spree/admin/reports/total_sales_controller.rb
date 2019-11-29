module Spree
  module Admin
    module Reports
      class TotalSalesController < Spree::Admin::BaseController
        def show
          orders = Spree::Admin::Reports::TotalSalesQuery.new.call

          respond_to do |format|
            format.html
            format.json do
              render json: Spree::Admin::Reports::TotalSales::JsonSerializer.new.call(orders)
            end
          end
        end
      end
    end
  end
end
