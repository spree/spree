# Permission set for viewing users and related information.
#
# This permission set provides read-only access to user accounts,
# addresses, and credit cards.
#
# @example
#   Spree.permissions.assign(:support_staff, Spree::PermissionSets::UserDisplay)
#
module Spree
  module PermissionSets
    class UserDisplay < Base
      def activate!
        can [:read, :admin, :index], Spree.customer_class
        can [:read, :admin], Spree::Address
        can [:read, :admin], Spree::CreditCard
        can [:read, :admin], Spree::Company
        can [:read, :admin], Spree::CompanyLocation
        can [:read, :admin], Spree::CompanyContact
        can [:read, :admin], Spree::TaxExemptionCertificate
      end
    end
  end
end
