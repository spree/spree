module Spree
  module Api
    module V3
      # Turns a CanCanCan ability into the flat, JSON-safe shape the panels'
      # `<Can>` reads. Shared by every `/me` endpoint — the admin and seller
      # branches answer different audiences, but the frontend permission model
      # is one implementation, so its input has to be too.
      #
      # - Subjects are short names (`product`), not Ruby class names.
      # - Rule order is preserved so the frontend matcher can apply
      #   CanCanCan's "last matching rule wins" semantics.
      # - Per-record conditions are NOT serialized (they often reference
      #   scopes or blocks that don't translate to JSON). The frontend
      #   receives `has_conditions: true` as a hint that the action might be
      #   denied at the per-record level — in practice the SPA shows the
      #   action optimistically and handles 403 from the API.
      module PermissionSerialization
        extend ActiveSupport::Concern

        private

        def serialize_permissions(ability)
          ability.send(:rules).map do |rule|
            {
              allow: rule.base_behavior,
              actions: Array(rule.actions).map(&:to_s),
              subjects: Array(rule.subjects).map { |subject| serialize_subject(subject) },
              has_conditions: rule_has_conditions?(rule)
            }
          end
        end

        # A model subject travels as its short name (`product`, `customer`),
        # never the Ruby class; `all` and symbol subjects (`dashboard`) pass
        # through as they are.
        def serialize_subject(subject)
          subject.is_a?(Class) ? Spree::Base.polymorphic_api_type(subject.name) : subject.to_s
        end

        def serialize_permission_keys(ability)
          ability.respond_to?(:permission_keys) ? ability.permission_keys : []
        end

        def rule_has_conditions?(rule)
          rule.block.present? || rule.conditions.present?
        end
      end
    end
  end
end
