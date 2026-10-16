module Spree
  module Api
    module V3
      module Admin
        class TaxExemptionReasonCodeSerializer < V3::BaseSerializer
          # A value object, not a record — it has no id of its own.
          _attributes.delete(:id)

          typelize value: [:string, comment: 'Stored on the certificate as `reason_code`, e.g. `G` or `resale`.'],
                   label: [:string, comment: 'What the merchant reads, as the provider names it.']

          attributes :value, :label
        end
      end
    end
  end
end
