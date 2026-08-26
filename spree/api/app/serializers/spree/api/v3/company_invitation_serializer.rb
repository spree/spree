module Spree
  module Api
    module V3
      # A pending (or spent) invitation into a company node. The token is
      # deliberately absent — it travels only in the invite email.
      class CompanyInvitationSerializer < BaseSerializer
        typelize email: :string, company_id: :string, status: :string,
                 expires_at: [:string, nullable: true]

        attributes :email, expires_at: :iso8601

        attribute :company_id do |invitation|
          invitation.company.prefixed_id
        end

        # Derived, not a column: expiry is a date fact, acceptance and
        # revocation are stamps.
        attribute :status do |invitation|
          if invitation.accepted? then 'accepted'
          elsif invitation.revoked? then 'revoked'
          elsif invitation.expired? then 'expired'
          else 'pending'
          end
        end
      end
    end
  end
end
