module Spree
  module Api
    module V3
      module Store
        module Concerns
          # The address book surface names its default flags without the
          # `is_` the address services use, so the two are translated here —
          # and only where the client actually said something, since silence
          # means "leave the pointer alone" rather than "clear it".
          module CompanyAddressDefaults
            extend ActiveSupport::Concern

            protected

            # @return [Hash] keywords for Spree::Addresses::Create / Update
            def default_flags
              flags = {}
              flags[:default_billing] = flag_param(:default_billing) unless flag_param(:default_billing).nil?
              flags[:default_shipping] = flag_param(:default_shipping) unless flag_param(:default_shipping).nil?
              flags
            end

            # @return [Boolean, nil] nil when the client said nothing about it
            def flag_param(name)
              return nil unless params.key?(name)

              ActiveModel::Type::Boolean.new.cast(params[name])
            end
          end
        end
      end
    end
  end
end
