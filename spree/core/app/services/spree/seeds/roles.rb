module Spree
  module Seeds
    # A role belongs to what it governs, so every store gets its own
    # immutable admin.
    class Roles
      prepend Spree::ServiceModule::Base
      include StoreScoped

      private

      def seed(store)
        admin = Spree::Role.default_admin_role(store)
        admin.update_column(:mutable, false) if admin.read_attribute(:mutable)
      end
    end
  end
end
