module Spree
  class PromotionCategory < Spree::Base
    validates :name, presence: true
    has_many :promotions
  end
end
