module Spree
  module Api
    module V3
      # A pending (or spent) invitation into a company node. The token is
      # deliberately absent — it travels only in the invite email.
      class CompanyInvitationSerializer < BaseSerializer
        typelize email: :string, company_id: :string, status: [:string, enum: %w[pending accepted revoked expired], enum_type_name: 'CompanyInvitationStatus'],
                 expires_at: [:string, nullable: true],
                 company_name: [:string, optional: true, deprecated: 'Expand `company` and read its `name`. Removed in 6.5.'],
                 store_name: [:string, optional: true, deprecated: "Read the store's `name` from `GET /api/v3/store/store`. Removed in 6.5."]

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

        one :company, resource: proc { Spree.api.company_serializer }, if: proc { expand?('company') }

        # Sent only by the token lookup, which named the company and the store
        # before `company` could be expanded.
        attribute(:company_name, if: proc { params[:invitee] }) { |invitation| invitation.company.name }
        attribute(:store_name, if: proc { params[:invitee] }) { current_store.name }
      end
    end
  end
end
