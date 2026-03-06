module Spree
  module Api
    module V3
      module Admin
        class RefundSerializer < V3::RefundSerializer
          typelize metadata: 'Record<string, unknown> | null'

          attribute :metadata do |refund|
            refund.metadata.presence
          end
        end
      end
    end
  end
end
