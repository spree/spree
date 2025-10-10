module Spree
  class PromotionCategory < Spree.base_class
    validates :name, presence: true
    has_many :promotions
  end
end
