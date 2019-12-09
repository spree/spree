module Spree
  module Admin
    module Reports
      class TotalOrdersController < Spree::Admin::BaseController
        def show
          objects = Spree::Admin::Reports::Orders::TotalOrders.new(params).call

          respond_to do |format|
            format.html
            format.json do
              render json: Spree::Admin::Reports::TotalOrders::JsonSerializer.new.call(objects)
            end
            format.csv do
              render plain: Spree::Admin::Reports::TotalOrders::CsvSerializer.new.call(objects)
            end
          end
        end
      end
    end
  end
end
