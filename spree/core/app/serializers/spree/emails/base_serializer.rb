module Spree
  module Emails
    # Base for the serializers that feed email templates. Emails read plain
    # JSON, the same data a renderer outside Ruby would receive, never models.
    # Never expose a token here: URLs carrying secrets are built by the mailer.
    class BaseSerializer
      include Alba::Resource

      attribute :id do |object|
        object.prefixed_id if object.respond_to?(:prefixed_id)
      end
    end
  end
end
