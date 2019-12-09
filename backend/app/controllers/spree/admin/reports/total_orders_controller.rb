module Spree
  module Admin
    module Reports
      class TotalOrdersController < Spree::Admin::BaseController
        def show
          respond_to do |format|
            format.html
            format.json do
              render json: Spree::Admin::Reports::TotalOrders::JsonSerializer.new.call(filtered_data)
            end
            format.csv do
              render plain: Spree::Admin::Reports::TotalOrders::CsvSerializer.new.call(filtered_data)
            end
          end
        end

        private

        def filtered_data
          Spree::Admin::Reports::Orders::TotalOrders.new(params).call
        end
      end
    end
  end
end
