module Spree
  module Api
    module V3
      # Writing an entry in a company node's address book, on either API.
      #
      # An entry is an ordinary address the node owns, so the payload is
      # address attributes plus the label it is filed under. The two defaults
      # are not columns on the row — they are pointers on the node — so they
      # travel to the address services as flags, which apply them once the
      # address itself is written.
      module CompanyAddressWrites
        extend ActiveSupport::Concern
        include AddressDefaultFlags

        protected

        # Each including controller declares the address it takes with
        # `request_params`.
        def permitted_params
          params.permit(*declared_permitted_attributes)
        end

        # @return [Hash] default keywords for Spree::Addresses::Create / Update
        def default_flags
          { default_billing: flag_param(:default_billing), default_shipping: flag_param(:default_shipping) }
        end
      end
    end
  end
end
