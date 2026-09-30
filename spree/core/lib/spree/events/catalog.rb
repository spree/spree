# frozen_string_literal: true

module Spree
  module Events
    # Raised in development and test when code publishes an event that no model
    # declared with `publishes_event`.
    class UndeclaredEventError < StandardError; end

    # Every event Spree publishes, declared once on the model whose record is the
    # payload (`publishes_events` / `publishes_event` / `publishes_lifecycle_events`).
    #
    # The catalog is the single source for the webhook event types generated into
    # `@spree/sdk/webhooks`, the Admin API list of subscribable events and the
    # rule that keeps credential-carrying events off wildcard webhook endpoints.
    class Catalog
      # One declared event.
      #
      # @!attribute name [String] the full event name, e.g. `order.placed`
      # @!attribute model_name [String] the declaring model's class name
      # @!attribute serializer_name [String, nil] the serializer named in the declaration, if any
      # @!attribute credential_permission [String, nil] for an event carrying a live
      #   credential, the permission needed to point a webhook endpoint at it
      # @!attribute deprecated_alias_of [String, nil] the event this one duplicates, when deprecated
      Entry = Data.define(:name, :model_name, :serializer_name, :credential_permission, :deprecated_alias_of) do
        # The resource segment of the name, used to group events for display.
        #
        # @return [String] e.g. `order` for `order.placed`
        def group
          name.split('.').first
        end

        # Whether the payload carries a live credential (a password reset token),
        # which a webhook endpoint receives only when it names the event outright.
        #
        # @return [Boolean]
        def credential?
          credential_permission.present?
        end

        # @return [Boolean]
        def deprecated?
          deprecated_alias_of.present?
        end

        # The serializer that builds the payload: the declared one, or the model's
        # Store serializer resolved the way `Spree::Publishable#event_payload` does.
        # Nil when there is none — the payload is then only the record's `id`,
        # `created_at` and `updated_at` — or when `spree_api` is not installed.
        #
        # @return [Class, nil]
        def payload_serializer
          serializer_name&.safe_constantize || model_name.constantize.allocate.event_serializer_class
        end
      end

      def initialize
        @declarations = {}
      end

      # Declare an event for a model. A bare action (`:placed`) is prefixed with
      # the model's event prefix when the catalog is read, so a prefix assigned
      # later in the class body still applies; a dotted name is used as given.
      #
      # Re-declaring the same model and name replaces the earlier declaration,
      # which keeps the catalog correct across code reloads.
      #
      # @param model [Class] the model whose record is the payload
      # @param name [Symbol, String] an action or a full event name
      # @param options [Hash] `serializer:`, `credential:` (the permission key
      #   required to receive it), `deprecated_alias_of:`
      # @return [void]
      def declare(model, name, **options)
        # A named class is keyed by its name so a reloaded class replaces its
        # stale copy; an anonymous one (a spec's `Class.new`) by the class.
        @declarations[[model.name || model, name.to_s]] = options
        @entries = @sorted = nil
      end

      # @param name [String]
      # @return [Entry, nil]
      def find(name)
        entries[name.to_s]
      end

      # Every declared event, sorted by name.
      #
      # @return [Array<Entry>]
      def all
        load!
        @sorted ||= entries.values.sort_by(&:name)
      end

      # @param name [String]
      # @return [Boolean]
      def credential?(name)
        find(name)&.credential? || false
      end

      # Events whose payload carries a live credential, optionally only those
      # among the given names.
      #
      # @param names [Array<String>, nil]
      # @return [Array<Entry>]
      def credential_events(names = nil)
        events = all.select(&:credential?)
        names ? events.select { |entry| names.include?(entry.name) } : events
      end

      # Checks that an event about to be published is declared. Raises
      # {UndeclaredEventError} in development and test, logs a warning otherwise.
      #
      # @param name [String]
      # @return [void]
      def verify_declared!(name)
        return if find(name)

        # A class declared before it had a name is only listed once it has one,
        # so a miss rebuilds once — and only while anonymous declarations exist.
        if !@loaded || @declarations.each_key.any? { |model_key, _| model_key.is_a?(Class) }
          @entries = @sorted = nil
          load!
          return if find(name)
        end

        message = "Spree event #{name.inspect} is not declared. Declare it with `publishes_event` on the model whose record is the payload."
        raise UndeclaredEventError, message if Spree::Events.raise_on_undeclared_events

        Rails.logger.warn("[Spree Events] #{message}")
      end

      # Loads every model so the catalog holds all declarations, which only
      # matters where Rails does not eager load (development and test).
      #
      # @return [void]
      def load!
        return if @loaded

        @loaded = true
        Rails.application.eager_load! unless Rails.application.config.eager_load
      end

      private

      def entries
        @entries ||= @declarations.each_with_object({}) do |((model_key, name), options), result|
          model = model_key.is_a?(Class) ? model_key : model_key.safe_constantize
          next unless model&.name

          # A parent and its subclass can declare the same name; the parent,
          # declared first, stays the owner.
          full_name = name.include?('.') ? name : "#{model.event_prefix}.#{name}"
          result[full_name] ||= Entry.new(
            name: full_name, model_name: model.name, serializer_name: options[:serializer],
            credential_permission: options[:credential], deprecated_alias_of: options[:deprecated_alias_of]
          )
        end
      end
    end
  end
end
