class Spree::PromotionCode < ActiveRecord::Base
  belongs_to :promotion
  has_many :adjustments

  validates :usage_limit, numericality: { greater_than: 0, allow_nil: true }
  validates :value, presence: true, uniqueness: true
  validates :promotion_id, presence: true
end
