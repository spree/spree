module Spree
  # Adds class-level helpers that surface a JSON-friendly description of
  # a `Preferable` class's `preference :name, :type, default:` declarations.
  #
  # Used by the admin API (`/payment_methods/types`, `/promotion_actions/types`,
  # `/promotion_rules/types`) so that admin UIs can render configuration forms
  # for any provider/action/rule subclass without hard-coding field lists.
  module PreferenceSchema
    extend ActiveSupport::Concern

    delegate :preference_schema, :serialized_preference_schema, :password_preference_keys, to: :class

    # Wire-safe view of `preferences` with `:password`-typed values
    # masked. Lives here (not in the serializer) so any consumer holding
    # a Preferable instance gets the same safety guarantee — secrets
    # must never leave the server in plaintext. Keys are stringified to
    # match the wire shape expected by JSON clients.
    #
    # @return [Hash{String => Object}]
    def serialized_preferences
      Spree::Preferences::Masking.serialize(self)
    end

    class_methods do
      # Returns `[{ key:, type:, default: }]` for every preference declared
      # on this class (and its ancestors). Skips deprecated preferences.
      #
      # Memoized at class load — the schema is derived from the static
      # `preference :name, :type` declarations, so it can never change at
      # runtime. Each entry also caches `key_string` (frozen) so hot-path
      # serializers don't allocate `pref.to_s` per request.
      def preference_schema
        @preference_schema ||= compute_preference_schema
      end

      # Wire-safe variant of `preference_schema` with `:password`
      # defaults nilled out. A gateway author can set a non-empty
      # default for a `:password` preference; without this redaction the
      # default leaks alongside the masked live value. Memoized so admin
      # index responses don't re-allocate per row.
      #
      # Strips `:key_string` — that's a server-only cache used by
      # `Masking.serialize` to avoid `to_s` allocations per request, not
      # part of the documented `{ key, type, default }` wire shape.
      def serialized_preference_schema
        @serialized_preference_schema ||= preference_schema.map do |field|
          wire = { key: field[:key], type: field[:type], default: field[:default] }
          wire[:default] = nil if field[:type] == :password
          wire.freeze
        end.freeze
      end

      # Set of `:password`-typed preference keys for this class. Memoized
      # so write-side guards (e.g. the masked-round-trip check) don't
      # walk the schema or fall back to a `rescue NoMethodError`.
      def password_preference_keys
        @password_preference_keys ||= preference_schema
                                      .each_with_object(Set.new) { |field, set| set << field[:key] if field[:type] == :password }
                                      .freeze
      end

      def compute_preference_schema
        instance = new
        instance.defined_preferences.filter_map do |pref|
          next if instance.preference_deprecated(pref)

          {
            key: pref,
            key_string: pref.to_s.freeze,
            type: instance.preference_type(pref),
            default: safe_preference_default(instance, pref)
          }.freeze
        end
      rescue StandardError
        []
      end

      # Resolve a wire-format shorthand back to its registered subclass.
      # Returns nil for unknown shorthands. Lookup is registry-driven so
      # removed/foreign subclasses can't be smuggled in.
      def find_by_api_type(shorthand)
        return nil if shorthand.blank?

        registered_subclasses.find { |klass| klass.api_type == shorthand.to_s }
      end

      # Returns a `[{ type:, label:, description:, preference_schema: }]`
      # array for every concrete subclass in `subclasses`. Sorted by label
      # for stable output. Uses `serialized_preference_schema` so
      # `:password` defaults are redacted — `/types` is an unauthenticated
      # discovery surface and must never leak gateway-shipped defaults.
      def subclasses_with_preference_schema
        registered_subclasses.map do |klass|
          {
            type: klass.api_type,
            label: subclass_label(klass),
            description: klass.respond_to?(:description) ? klass.description : nil,
            preference_schema: klass.respond_to?(:serialized_preference_schema) ? klass.serialized_preference_schema : []
          }
        end.sort_by { |entry| entry[:label] }
      end

      # STI subclasses share the parent's `model_name`, so calling
      # `klass.model_name.human` would return "Payment Method" for every
      # entry. Subclasses can override by defining a class-level
      # `display_name`. Otherwise:
      #
      #   Spree::PaymentMethod::Check       → "Check"
      #   Spree::Gateway::Bogus             → "Bogus"
      #   SpreeStripe::Gateway              → "Stripe"
      #   SpreeAdyen::Gateway               → "Adyen"
      #
      # The "Gateway" branch handles the gem convention where each
      # provider gem ships a top-level `Gateway` class (so demodulize
      # would collapse them all to "Gateway"). Fall back to the outer
      # module, with a leading `Spree` namespace stripped.
      def subclass_label(klass)
        return klass.display_name if klass.respond_to?(:display_name) && klass.display_name.present?
        return klass.human_name if klass.respond_to?(:human_name) && klass.human_name.present?

        leaf = klass.to_s.demodulize
        return leaf.titleize unless leaf == 'Gateway'

        outer = klass.to_s.split('::').first.to_s
        outer.delete_prefix('Spree').presence&.titleize || leaf.titleize
      end

      private

      # Each STI parent (PaymentMethod, PromotionAction, PromotionRule)
      # already exposes its registry — we just route to the right one.
      # Override in the including class to add support for custom parents.
      def registered_subclasses
        return providers if respond_to?(:providers)
        return Spree.promotions.actions if name == 'Spree::PromotionAction'
        return Spree.promotions.rules if name == 'Spree::PromotionRule'

        []
      end

      # Defaults can be Procs that hit the database (e.g. `Spree::Store.default`);
      # those aren't safe to evaluate at request time, so we stringify them.
      def safe_preference_default(instance, pref)
        instance.preference_default(pref)
      rescue StandardError
        nil
      end
    end
  end
end
