module Spree
  module Api
    module V3
      # Reads the flags that move an owner's default billing and shipping
      # addresses, for every endpoint that writes to an address book.
      module AddressDefaultFlags
        extend ActiveSupport::Concern

        protected

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
