module Spree
  module Api
    module V3
      module Admin
        # The store's rollup plus what each product contributes to it — the
        # breakdown a merchant checks a forwarder's quote against, and the
        # reason the store shape carries totals alone.
        class FreightSummarySerializer < V3::FreightSummarySerializer
          typelize lines: [:FreightSummaryLine, multi: true]

          many :lines, resource: proc { Spree.api.admin_freight_summary_line_serializer }
        end
      end
    end
  end
end
