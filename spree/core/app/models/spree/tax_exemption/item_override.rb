module Spree
  class TaxExemption
    # A single line's departure from its exemption entry — most often carving a
    # line out (+exempt: false+ for the own-use item in a resale order), and
    # optionally giving it a reason of its own.
    class ItemOverride
      include ActiveModel::Model
      include ActiveModel::Attributes

      # Prefixed id of the line item, fulfillment or fee this applies to.
      attribute :item_id, :string
      attribute :exempt, :boolean, default: true
      attribute :reason_code, :string

      validates :item_id, presence: true

      def exempt?
        exempt
      end
    end
  end
end
