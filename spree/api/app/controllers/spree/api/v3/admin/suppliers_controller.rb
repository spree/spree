module Spree
  module Api
    module V3
      module Admin
        # The merchant's supplier address book. Buying goods in is its own
        # permission resource: `write_stock` moves the stock you have, and must
        # not also mean "may place orders with suppliers".
        class SuppliersController < ResourceController
          scoped_resource :purchasing

          protected

          def model_class
            Spree::Supplier
          end

          def serializer_class
            Spree.api.admin_supplier_serializer
          end

          def resource_permitted_attributes
            [:name, :contact_name, :email, :phone, :notes,
             :address1, :address2, :city, :state_name, :state_code,
             :country_code, :postal_code, { metadata: {} }]
          end
        end
      end
    end
  end
end
