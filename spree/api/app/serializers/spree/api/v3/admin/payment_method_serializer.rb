module Spree
  module Api
    module V3
      module Admin
        class PaymentMethodSerializer < V3::PaymentMethodSerializer
          typelize active: :boolean,
                   auto_capture: [:boolean, nullable: true],
                   display_on: :string,
                   position: :number,
                   metadata: 'Record<string, unknown>',
                   preferences: 'Record<string, unknown>',
                   preference_schema: "Array<{ key: string; type: string; default: unknown }>"

          attributes :metadata, :active, :auto_capture, :display_on, :position,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :preferences, &:serialized_preferences
          attribute :preference_schema, &:serialized_preference_schema
        end
      end
    end
  end
end
