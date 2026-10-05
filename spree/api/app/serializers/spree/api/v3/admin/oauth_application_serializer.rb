module Spree
  module Api
    module V3
      module Admin
        # Admin API serializer for {Spree::OauthApplication}.
        #
        # Never exposes `secret` or `uid`: a client is pre-registered, and the
        # screen this feeds is about taking access away rather than
        # reconfiguring it.
        #
        # `scopes` and `last_used_at` come from the live tokens rather than
        # the registration — a client is registered once and granted per
        # consent, so what the merchant approved lives on the token.
        class OauthApplicationSerializer < V3::BaseSerializer
          typelize name: :string,
                   scopes: [:string, multi: true],
                   last_used_at: [:string, nullable: true],
                   authorized_at: [:string, nullable: true],
                   authorized_by: [:string, nullable: true],
                   redirect_uri: [:string, nullable: true]

          attributes :name, :redirect_uri, created_at: :iso8601, updated_at: :iso8601

          attribute :scopes do |application|
            application.live_token_scopes
          end

          attribute :last_used_at do |application|
            application.last_used_at&.iso8601
          end

          attribute :authorized_at do |application|
            application.authorized_at&.iso8601
          end

          # Who allowed this, in the words a person is known by. On the screen
          # that decides whether to revoke, the permission alone is half the
          # story.
          attribute :authorized_by do |application|
            application.authorized_by.try(:actor_label)
          end
        end
      end
    end
  end
end
