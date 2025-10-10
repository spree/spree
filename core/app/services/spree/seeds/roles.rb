module Spree
  module Seeds
    class Roles
      prepend Spree::ServiceModule::Base

      def call
        Spree::Role.where(name: 'admin').first_or_create!
      end
    end
  end
end
