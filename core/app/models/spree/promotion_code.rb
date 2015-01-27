class Spree::PromotionCode < ActiveRecord::Base
  belongs_to :promotion

  validates :usage_limit, numericality: { greater_than: 0, allow_nil: true }

  before_save :normalize_blank_values

  def expired?
    !!(starts_at && Time.now < starts_at || expires_at && Time.now > expires_at)
  end

  def eligible?(promotable)
    return false if expired? || usage_limit_exceeded?(promotable) || blacklisted?(promotable)
    !!eligible_rules(promotable, {})
  end

  def usage_limit_exceeded?
    false
  end

  private

  def normalize_blank_values
    self[:value] = nil if self[:value].blank?
  end
end
