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

    # The kinds core itself registers, for the generated `ActorKind` type.
    #
    # A literal list rather than one derived from `Spree.actor_classes`: that
    # registry is filled after serializer classes load, so deriving it would
    # make the generated types depend on boot order and on which extensions
    # are installed. The union stays open on the wire, so an extension's kind
    # is still a valid value — it just does not autocomplete.
    BUILT_IN_KINDS = %w[admin_user api_key].freeze

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
    # Read from `polymorphic_name`, which is what the `*_type` column stores,
    # so an STI subclass of an actor answers the same kind on the expansion
    # as it does in the column beside it.
    #
    # @return [String]
    def actor_kind
      Spree::Base.polymorphic_api_type(self.class.polymorphic_name)
    end
  end
end
