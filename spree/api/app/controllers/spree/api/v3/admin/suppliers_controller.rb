module Spree
  module Api
    module V3
      module Admin
        # The merchant's supplier address book. Buying goods in is its own
        # permission resource: `write_stock` moves the stock you have, and must
        # not also mean "may place orders with suppliers".
        class SuppliersController < ResourceController
          scoped_resource :purchasing

          request_params :supplier do |body|
            body.attribute :name, :string, required: true, on: :create, example: 'Northwind Trading'
            body.attribute :contact_name, :string, nullable: true, example: 'Dana Okafor'
            body.attribute :email, :string, nullable: true, example: 'sales@northwind.test'
            body.attribute :phone, :string, nullable: true, example: '555-0100'
            body.attribute :notes, :string, nullable: true
            body.attribute :address1, :string, nullable: true, example: '1 Warehouse Way'
            body.attribute :address2, :string, nullable: true
            body.attribute :city, :string, nullable: true, example: 'Brooklyn'
            body.attribute :state_name, :string, nullable: true
            body.attribute :state_code, :string, nullable: true, example: 'NY'
            body.attribute :country_code, :country, nullable: true, example: 'US'
            body.attribute :postal_code, :string, nullable: true, example: '11201'
            body.attribute :metadata, :hash, nullable: true
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
