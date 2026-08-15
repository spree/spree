module Spree
  module Seeds
    class Roles
      prepend Spree::ServiceModule::Base

      # Roles are store-owned, so every store gets its own immutable admin.
      def call
        Spree::Store.find_each do |store|
          admin = Spree::Role.staff.where(store: store).where(name: Spree::Role::ADMIN_ROLE).first_or_create!
          admin.update_column(:mutable, false) if admin.read_attribute(:mutable)
        end
      end
    end
  end
end
