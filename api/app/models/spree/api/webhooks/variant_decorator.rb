module Spree
  module Api
    module Webhooks
      module VariantDecorator
        def self.prepended(base)
          def base.custom_webhook_events
            %w[variant.back_in_stock variant.backorderable variant.discontinued variant.out_of_stock]
          end
        end

        def discontinue!
          super
          queue_webhooks_requests!('variant.discontinued')
        end
      end
    end
  end
end

Spree::Variant.prepend(Spree::Api::Webhooks::VariantDecorator)
