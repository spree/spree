module Spree
  class PromotionCategory < Spree.base_class
    has_prefix_id :procat

    validates :name, presence: true
    has_many :promotions
  end
end
