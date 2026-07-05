module Spree
  # Legacy join between Store and PaymentMethod. Superseded by the single-store
  # +PaymentMethod#store+ FK in 5.6; retained only so the +spree_multi_store+
  # extension can restore +has_many :stores+ and so the backfill task can read
  # historic attachments. Dropped in 6.0.
  class StorePaymentMethod < Spree.base_class
    self.table_name = 'spree_payment_methods_stores'

    belongs_to :store, class_name: 'Spree::Store', touch: true
    belongs_to :payment_method, class_name: 'Spree::PaymentMethod', touch: true

    validates :store, :payment_method, presence: true
    validates :store_id, uniqueness: { scope: :payment_method_id }
  end
end
