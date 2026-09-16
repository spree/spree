module Spree
  # What a model must answer to be recorded as the performer of an action.
  #
  # Included in the admin user class and in {Spree::ApiKey}; an extension's App
  # or bot class includes it too and registers itself in
  # `Spree.actor_classes` (see docs/plans/6.0-action-actors.md).
  #
  # Both methods have defaults that read whatever the including class already
  # offers, so a class that names itself in one of the usual ways needs no
  # override.
  module Actor
    extend ActiveSupport::Concern

    # How a timeline names this actor: a person's full name or email, an API
    # key's name, an app's title.
    #
    # @return [String, nil]
    def actor_label
      %i[full_name name email].each do |method|
        next unless respond_to?(method)

        value = public_send(method)
        value = value.to_s if value.present?
        return value if value.present?
      end

      nil
    end

    # The wire shorthand for this actor's kind — `admin_user`, `api_key`, …
    # The same derivation every polymorphic type column on the Admin API uses.
    #
    # @return [String]
    def actor_kind
      Spree::Base.polymorphic_api_type(self.class.name)
    end
  end
end
