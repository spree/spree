module Spree
  module Seeds
    # Seeds only what has no Admin API by design: the store row, its immutable
    # admin role, its first publishable key and the first admin. Everything a
    # store trades with — tax categories, channels, reasons, the warehouse,
    # delivery zones — is the configurator's store defaults, deployed once the
    # store knows where it sells from (docs/plans/6.0-cli-configurator.md).
    class All
      prepend Spree::ServiceModule::Base

      def call
        Spree::Events.disable do
          ActiveRecord::Base.no_touching do
            Stores.call
            Roles.call
            ApiKeys.call
            AdminUser.call
          end
        end
      end
    end
  end
end
