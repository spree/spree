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

        protected

        def permitted_params
          params.permit(:label, *Spree::Api::V3::AddressParams::ADDRESS_KEYS)
        end

        # @return [Hash] default keywords for Spree::Addresses::Create / Update
        def default_flags
          { default_billing: flag_param(:default_billing), default_shipping: flag_param(:default_shipping) }
        end

        # Each flag has three meanings and they are all different: true claims
        # the slot, false gives it up, and saying nothing leaves it alone.
        #
        # @return [Boolean, nil] nil when the client said nothing about it
        def flag_param(name)
          return nil unless params.key?(name)

          ActiveModel::Type::Boolean.new.cast(params[name])
        end
      end
    end
  end
end
