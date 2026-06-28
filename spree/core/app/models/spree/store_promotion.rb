module Spree
  # Legacy join between Store and Promotion. Superseded by the single-store
  # +Promotion#store+ FK in 5.6; retained only so the +spree_multi_store+
  # extension can restore +has_many :stores+ and so the backfill task can read
  # historic attachments. Dropped in 6.0.
  class StorePromotion < Spree.base_class
    self.table_name = 'spree_promotions_stores'

    belongs_to :store, class_name: 'Spree::Store', touch: true
    belongs_to :promotion, class_name: 'Spree::Promotion', touch: true

    validates :store, :promotion, presence: true
    validates :store_id, uniqueness: { scope: :promotion_id }
  end
end
