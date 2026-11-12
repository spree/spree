module Spree
  module Api
    module V3
      module Admin
        # One person's live access through a connected client.
        #
        # The token itself is never serialized: it is a bearer credential, and
        # the screen that lists connections only needs to say whose access it
        # is and what that person approved.
        class OauthAccessTokenSerializer < V3::BaseSerializer
          typelize owner_id: [:string, nullable: true],
                   owner_type: [:string, nullable: true],
                   scopes: [:string, multi: true],
                   expired: :boolean

          attributes created_at: :iso8601

          # Who connected, without expanding: the id and the kind, so a
          # client can render a reference or follow it.
          attribute :owner_id do |token|
            token.resource_owner.try(:prefixed_id)
          end

          attribute :owner_type do |token|
            Spree::Base.polymorphic_api_type(token.resource_owner_type)
          end

          # Who connected, as the record itself rather than a summary of it,
          # so the dashboard shows a person the way it does everywhere else:
          # a name over an email, with an avatar.
          #
          # The serializer follows the record's kind, because a grant's owner
          # is polymorphic — an admin today, a customer when a storefront
          # client needs one. Alba hands the proc the object for exactly this.
          one :resource_owner,
              key: :owner,
              resource: proc { |owner| owner_serializer_for(owner) },
              if: proc { expand?('owner') }

          # @param owner [Object] the grant's resource owner
          # @return [Class] the serializer for that kind of owner
          def self.owner_serializer_for(owner)
            case Spree::Base.polymorphic_api_type(owner.class.name)
            when 'customer' then Spree.api.admin_customer_serializer
            else Spree.api.admin_admin_user_serializer
            end.to_s.constantize
          end

          # What this person approved, as permission keys.
          attribute :scopes do |token|
            token.scopes.to_a
          end

          # Whether the current access token has lapsed. The connection is
          # still live — a refresh mints another — but a merchant reading the
          # list deserves to know which agents hold access right now.
          attribute :expired, &:expired?
        end
      end
    end
  end
end
