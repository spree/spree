module Spree
  class StorePaymentMethod < Spree::Base
    self.table_name = 'spree_payment_methods_stores'

    belongs_to :store, class_name: 'Spree::Store', touch: true
    belongs_to :payment_method, class_name: 'Spree::PaymentMethod', touch: true

    validates :store, :payment_method, presence: true
    validates :store_id, uniqueness: { scope: :payment_method_id }
  end
end
