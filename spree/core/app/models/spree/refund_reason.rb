module Spree
  # Why money went back — "Return processing", "Order Canceled". Store-owned
  # like {Spree::ReturnReason} and {Spree::ClaimReason}.
  class RefundReason < Spree.base_class
    has_prefix_id :rr

    include Spree::NamedType
    include Spree::SingleStoreResource

    # Names are unique per store, not globally — two stores can each have
    # their own "Order Canceled" without colliding.
    validates :name, uniqueness: { case_sensitive: false, scope: [:store_id, *spree_base_uniqueness_scope] }

    self.whitelisted_ransackable_attributes = %w[name active mutable]

    RETURN_PROCESSING_REASON = 'Return processing'.freeze
    ORDER_CANCELED_REASON = 'Order Canceled'.freeze
    SHIPMENT_CANCELED_REASON = 'Shipment Canceled'.freeze

    has_many :refunds, class_name: 'Spree::Refund', dependent: :restrict_with_error

    class << self
      # The seeded reasons core attaches to refunds it issues itself.
      #
      # Each takes the store explicitly rather than reading
      # `Spree::Current.store`: these are called from workflows that already
      # hold the record's store, and a background job or console session has
      # no current store to fall back on — which would silently create the
      # reason against the wrong one.
      def return_processing_reason(store = Spree::Current.store)
        seeded(RETURN_PROCESSING_REASON, store)
      end

      def order_canceled_reason(store = Spree::Current.store)
        seeded(ORDER_CANCELED_REASON, store)
      end

      def shipment_canceled_reason(store = Spree::Current.store)
        seeded(SHIPMENT_CANCELED_REASON, store)
      end

      private

      def seeded(name, store)
        where(store: store).find_or_create_by(name: name) do |reason|
          reason.mutable = false
        end
      end
    end
  end
end
