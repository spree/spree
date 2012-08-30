module Spree
  module Admin
    module UsersHelper
      def list_roles(user)
        # while testing spree-core itself user model does not have method roles
        user.respond_to?(:spree_roles) ? user.spree_roles.collect { |role| role.name }.join(", ") : []
      end
    end
  end
end
