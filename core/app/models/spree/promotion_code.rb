class Spree::PromotionCode < ActiveRecord::Base
  belongs_to :promotion

  validates :promotion, :value, presence: true
  validates :usage_limit, numericality: { greater_than: 0, allow_nil: true }

  before_save :normalize_value

  def expired?
    !!(starts_at && Time.now < starts_at || expires_at && Time.now > expires_at)
  end

  def eligible?(promotable)
    !expired? && !usage_limit_exceeded?(promotable)
  end

  def usage_limit_exceeded?(promotable)
    false
  end

  private

  def normalize_value
    self[:value] = self[:value].strip.downcase
  end
end
