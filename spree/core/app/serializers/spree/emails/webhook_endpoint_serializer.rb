module Spree
  module Emails
    # Never add the signing secret: an email must not carry it.
    class WebhookEndpointSerializer < BaseSerializer
      attributes :name, :url, :disabled_reason

      attribute :display_name do |endpoint|
        endpoint.name.presence || endpoint.url
      end

      attribute :disabled_at do |endpoint|
        endpoint.disabled_at&.iso8601
      end
    end
  end
end
