module Spree
  # Why an order was canceled — "Customer changed their mind", "Payment
  # declined", "Out of stock". Merchant-owned like {Spree::ReturnReason} and
  # {Spree::ClaimReason} rather than a fixed list, because nothing branches on
  # the value and every merchant cancels for reasons of their own.
  class OrderCancellationReason < Spree.base_class
    has_prefix_id :ocr

    include Spree::NamedType
    include Spree::Metadata

    self.whitelisted_ransackable_attributes = %w[name active]

    has_many :orders, class_name: 'Spree::Order', inverse_of: :cancel_reason,
                      foreign_key: :cancel_reason_id, dependent: :restrict_with_error

    # Mirrors what `dependent: :restrict_with_error` enforces, so the dashboard
    # can hide the delete control rather than offer one the model will refuse.
    #
    # @return [Boolean]
    def can_be_deleted?
      !orders.exists?
    end
  end
end
