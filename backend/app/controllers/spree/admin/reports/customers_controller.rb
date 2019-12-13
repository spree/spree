module Spree
  module Admin
    module Reports
      class CustomersController < Spree::Admin::BaseController
        def show
          respond_to do |format|
            format.html
            format.json do
              render json: Spree::Admin::Reports::TotalCustomers::JsonSerializer.new.call(filtered_data)
            end
            format.csv do
              send_data Spree::Admin::Reports::TotalCustomers::CsvSerializer.new.call(filtered_data), filename: 'customers.csv', disposition: 'attachment'
            end
          end
        end

        private

        def filtered_data
          Spree::Admin::Reports::Customers.new(params).call
        end
      end
    end
  end
end
