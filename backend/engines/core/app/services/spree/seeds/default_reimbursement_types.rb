module Spree
  module Seeds
    class DefaultReimbursementTypes
      prepend Spree::ServiceModule::Base

      def call
        # FIXME: we should use translations here
        Spree::RefundReason.find_or_create_by!(name: 'Return processing', mutable: false)
      end
    end
  end
end
