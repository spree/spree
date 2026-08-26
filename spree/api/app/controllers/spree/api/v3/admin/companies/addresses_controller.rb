module Spree
  module Api
    module V3
      module Admin
        module Companies
          # A node's address book — an entry is an ordinary address the node
          # owns, so the whole of it is reached through the node.
          class AddressesController < BaseController
            include Spree::Api::V3::Admin::Concerns::CompanyAddressParams

            before_action :authorize_parent_access!

            protected

            def model_class
              Spree::Address
            end

            def serializer_class
              Spree.api.admin_address_serializer
            end

            def scope
              @parent.addresses
            end

            def parent_association
              :addresses
            end
          end
        end
      end
    end
  end
end
