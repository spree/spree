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

      # @return [Hash]
      def to_snapshot
        attributes
      end

      # Unknown keys are dropped rather than raising: a snapshot is read back
      # long after it was written, possibly by a different version of Spree.
      #
      # @param snapshot [Hash]
      # @return [Spree::TaxExemption::ItemOverride]
      def self.from_snapshot(snapshot)
        new(snapshot.to_h.stringify_keys.slice(*attribute_names).symbolize_keys)
      end
    end
  end
end
