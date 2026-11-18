module Spree
  module Emails
    # Never add the token or its digest: an email must not carry a credential.
    class ApiKeySerializer < BaseSerializer
      attributes :name, :token_prefix, :scopes

      attribute :created_at do |api_key|
        api_key.created_at&.iso8601
      end

      attribute :created_by_name do |api_key|
        api_key.created_by.try(:actor_label)
      end
    end
  end
end
