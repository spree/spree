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
                   key_type: :string,
                   token_prefix: [:string, nullable: true],
                   plaintext_token: [:string, nullable: true],
                   scopes: [:string, multi: true],
                   revoked_at: [:string, nullable: true],
                   last_used_at: [:string, nullable: true],
                   created_by_email: [:string, nullable: true]

          attributes :name, :key_type, :token_prefix, :scopes,
                     created_at: :iso8601, updated_at: :iso8601,
                     revoked_at: :iso8601, last_used_at: :iso8601

          # Returned only on the create response — `plaintext_token` is held in
          # memory on the model after `generate_token` and is never persisted
          # for secret keys, so we serialize it whenever it's available rather
          # than gating on the action.
          attribute :plaintext_token do |key|
            key.plaintext_token
          end

          attribute :created_by_email do |key|
            key.created_by&.email
          end
        end
      end
    end
  end
end
