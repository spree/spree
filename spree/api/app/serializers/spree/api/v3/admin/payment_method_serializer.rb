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
                   logo_url: [:string, nullable: true],
                   docs_url: [:string, nullable: true],
                   third_party: :boolean

          # Null capture_method means the method inherits from its store;
          # resolved_capture_method is what actually applies, so the dashboard
          # can show the inherited value.
          attributes :metadata, :active, :auto_capture, :capture_method, :resolved_capture_method,
                     :storefront_visible, :position,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :preferences, &:serialized_preferences
          attribute(:logo_url) { |payment_method| payment_method.class.logo_url }
          attribute(:docs_url) { |payment_method| payment_method.class.docs_url }
          attribute(:third_party) { |payment_method| payment_method.class.third_party? }
        end
      end
    end
  end
end
