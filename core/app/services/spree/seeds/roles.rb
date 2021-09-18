module Spree
  module Seeds
    class Roles
      prepend Spree::ServiceModule::Base

      EXCLUDED_COUNTRIES = ['AQ', 'AX', 'GS', 'UM', 'HM', 'IO', 'EH', 'BV', 'TF'].freeze

      def call
        Spree::Role.where(name: 'admin').first_or_create!
        Spree::Role.where(name: 'user').first_or_create!
      end
    end
  end
end
