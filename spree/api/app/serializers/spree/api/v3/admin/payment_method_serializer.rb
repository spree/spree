module Spree
  module Api
    module V3
      module Admin
        class PaymentMethodSerializer < V3::PaymentMethodSerializer
          typelize active: :boolean,
                   auto_capture: [:boolean, nullable: true],
                   capture_method: "'checkout' | 'on_dispatch' | 'manual' | null",
                   resolved_capture_method: "'checkout' | 'on_dispatch' | 'manual'",
                   storefront_visible: :boolean,
                   position: :number,
                   metadata: 'Record<string, unknown>',
                   preferences: 'Record<string, unknown>',
                   preference_schema: "Array<{ key: string; type: string; default: unknown }>"

          # Null capture_method means the method inherits from its store;
          # resolved_capture_method is what actually applies, so the dashboard
          # can show the inherited value.
          attributes :metadata, :active, :auto_capture, :capture_method, :resolved_capture_method,
                     :storefront_visible, :position,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :preferences, &:serialized_preferences
          attribute :preference_schema, &:serialized_preference_schema
        end
      end
    end
  end
end
