module Spree
  module Seeds
    class Roles
      prepend Spree::ServiceModule::Base

      def call
        admin = Spree::Role.where(name: Spree::Role::ADMIN_ROLE).first_or_create!
        admin.update_column(:mutable, false) if admin.read_attribute(:mutable)
      end
    end
  end
end
