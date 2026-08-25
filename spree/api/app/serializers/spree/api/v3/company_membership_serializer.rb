module Spree
  module Api
    module V3
      # A person with standing over a company node, as the storefront
      # self-service surface lists them. Within a company OSS trusts every
      # member, so members see each other.
      class CompanyMembershipSerializer < BaseSerializer
        typelize role: :string, company_id: :string, customer_id: :string,
                 email: [:string, nullable: true]

        attributes :role

        # Both associations are required, so these are never null and the
        # types above say so.
        attribute :company_id do |membership|
          membership.company.prefixed_id
        end

        attribute :customer_id do |membership|
          membership.customer.prefixed_id
        end

        # Lists members by who they are without a customer request per row.
        attribute :email do |membership|
          membership.customer.email
        end
      end
    end
  end
end
