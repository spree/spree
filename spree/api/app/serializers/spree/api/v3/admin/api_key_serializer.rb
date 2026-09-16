module Spree
  module Api
    module V3
      module Admin
        # Admin API serializer for {Spree::ApiKey}.
        #
        # Never exposes `token` or `token_digest` — only the 12-char
        # `token_prefix` (e.g. `sk_abc123def`) so existing keys can be
        # identified in the UI without leaking material that would let an
        # attacker make requests. The full plaintext token is delivered
        # exactly once, as the response body of `POST /api/v3/admin/api_keys`,
        # via {#plaintext_token} below — it is `nil` everywhere else.
        class ApiKeySerializer < V3::BaseSerializer
          typelize name: :string,
                   key_type: [:string, enum: Spree::ApiKey::KEY_TYPES],
                   token_prefix: [:string, nullable: true],
                   plaintext_token: [:string, nullable: true],
                   scopes: [:string, multi: true],
                   revoked_at: [:string, nullable: true],
                   last_used_at: [:string, nullable: true],
                   created_by_email: [:string, nullable: true],
                   created_by_type: [:string, nullable: true, enum: Spree::Actor::BUILT_IN_KINDS, enum_type_name: 'ActorKind'],
                   created_by_label: [:string, nullable: true],
                   channel_id: [:string, nullable: true]

          attributes :name, :key_type, :token_prefix, :scopes,
                     created_at: :iso8601, updated_at: :iso8601,
                     revoked_at: :iso8601, last_used_at: :iso8601

          attribute :channel_id do |key|
            key.channel&.prefixed_id
          end

          # Returned only on the create response — `plaintext_token` is held in
          # memory on the model after `generate_token` and is never persisted
          # for secret keys, so we serialize it whenever it's available rather
          # than gating on the action.
          attribute :plaintext_token do |key|
            key.plaintext_token
          end

          # A key can be minted by another key, which has no email — so the
          # address is answered only for the actors that have one, and
          # `created_by_label` is what a list column should render.
          attribute :created_by_email do |key|
            key.created_by.try(:email)
          end

          attribute :created_by_type do |key|
            Spree::Base.polymorphic_api_type(key.created_by_type)
          end

          attribute :created_by_label do |key|
            key.created_by.try(:actor_label)
          end
        end
      end
    end
  end
end
