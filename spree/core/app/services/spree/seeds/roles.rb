module Spree
  module Seeds
    class Roles
      prepend Spree::ServiceModule::Base

      # A role belongs to what it governs, so every store gets its own
      # immutable admin.
      def call
        Spree::Store.find_each do |store|
          admin = Spree::Role.default_admin_role(store)
          admin.update_column(:mutable, false) if admin.read_attribute(:mutable)
        end
      end
    end
  end
end
