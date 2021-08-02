module Spree
  class StorePromotion < Spree::Base
    self.table_name = 'spree_promotions_stores'

    belongs_to :store, class_name: 'Spree::Store', touch: true
    belongs_to :promotion, class_name: 'Spree::Promotion', touch: true

    validates :store, :promotion, presence: true
    validates :store_id, uniqueness: { scope: :promotion_id }
  end
end
