module Spree
  module Api
    module V3
      module Admin
        # Admin API serializer for {Spree::Invitation}. Used on the staff
        # settings page to list pending invitations and to surface the result
        # of `POST /admin/invitations`. Inviter and invitee are flattened to
        # email-only — the full polymorphic identities aren't useful to the UI.
        class InvitationSerializer < V3::BaseSerializer
          typelize email: :string,
                   status: :string,
                   role_id: :string,
                   role_name: :string,
                   inviter_email: :string,
                   expires_at: :string,
                   acceptance_url: :string,
                   invitee_exists: :boolean,
                   store: '{ id: string; name: string }'

          attributes :email, :status,
                     created_at: :iso8601, updated_at: :iso8601, expires_at: :iso8601

          # `role`, `inviter` are `validates ... presence: true` on the model,
          # so they're guaranteed non-null for any persisted invitation.
          attribute :role_id do |invitation|
            invitation.role.prefixed_id
          end

          attribute :role_name do |invitation|
            invitation.role.name
          end

          attribute :inviter_email do |invitation|
            invitation.inviter.email
          end

          # Absolute URL when `Spree::Config[:admin_url]` is set, otherwise
          # the path so the SPA can prepend `window.location.origin`.
          attribute :acceptance_url do |invitation|
            if Spree::Config[:admin_url].present?
              Rails.application.routes.url_helpers.admin_invitation_acceptance_url(invitation)
            else
              "/accept-invitation/#{invitation.prefixed_id}?token=#{invitation.token}"
            end
          end

          # Drives the SPA's sign-in vs sign-up branch on the acceptance page.
          # Looked up by email so an admin who's already on another store sees
          # the password prompt, not a fresh account form.
          attribute :invitee_exists do |invitation|
            Spree.admin_user_class.exists?(email: invitation.email)
          end

          # Minimal store identity for the unauthenticated acceptance page's
          # title ("Join <store>"). Full Store would over-expose internals to
          # a public landing page; this is the smallest shape that renders.
          attribute :store do |invitation|
            { id: invitation.store.prefixed_id, name: invitation.store.name }
          end
        end
      end
    end
  end
end
