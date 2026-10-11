module Spree
  module Api
    module V3
      module Admin
        # The merchant's supplier address book. Buying goods in is its own
        # permission resource: `write_stock` moves the stock you have, and must
        # not also mean "may place orders with suppliers".
        class SuppliersController < ResourceController
          scoped_resource :purchasing

          request_params :supplier do
            string :name, required: :create, example: 'Northwind Trading'
            string :contact_name, nullable: true, example: 'Dana Okafor'
            string :email, nullable: true, example: 'sales@northwind.test'
            string :phone, nullable: true, example: '555-0100'
            string :notes, nullable: true
            string :address1, nullable: true, example: '1 Warehouse Way'
            string :address2, nullable: true
            string :city, nullable: true, example: 'Brooklyn'
            string :state_name, nullable: true
            string :state_code, nullable: true, example: 'NY'
            string :country_code, nullable: true, example: 'US'
            string :postal_code, nullable: true, example: '11201'
            object :metadata, nullable: true
          end

          protected

          def model_class
            Spree::Supplier
          end

          def serializer_class
            Spree.api.admin_supplier_serializer
          end
        end
      end
    end
  end
end
