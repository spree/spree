module Spree
  class PriceList < Spree::Base
    acts_as_paranoid

    STATUSES = %w[active inactive scheduled].freeze
    MATCH_POLICIES = %w[all any].freeze

    has_many :price_rules, class_name: 'Spree::PriceRule', dependent: :destroy
    has_many :prices, class_name: 'Spree::Price', dependent: :nullify

    validates :name, presence: true
    validates :priority, presence: true, numericality: { only_integer: true }
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :match_policy, presence: true, inclusion: { in: MATCH_POLICIES }
    validate :starts_at_before_ends_at

    scope :active, -> { where(status: 'active') }
    scope :inactive, -> { where(status: 'inactive') }
    scope :scheduled, -> { where(status: 'scheduled') }
    scope :by_priority, -> { order(priority: :desc) }
    scope :current, lambda {
      where('starts_at IS NULL OR starts_at <= ?', Time.current)
        .where('ends_at IS NULL OR ends_at >= ?', Time.current)
    }

    def self.for_context(context)
      active
        .current
        .by_priority
    end

    def applicable?(context)
      return false unless active_or_scheduled?
      return false unless within_date_range?(context.date || Time.current)

      rules_applicable?(context)
    end

    def rules_applicable?(context)
      return true if price_rules.none?

      case match_policy
      when 'all'
        price_rules.all? { |rule| rule.applicable?(context) }
      when 'any'
        price_rules.any? { |rule| rule.applicable?(context) }
      else
        false
      end
    end

    def active?
      status == 'active'
    end

    def inactive?
      status == 'inactive'
    end

    def scheduled?
      status == 'scheduled'
    end

    def active_or_scheduled?
      active? || scheduled?
    end

    private

    def starts_at_before_ends_at
      return if starts_at.blank? || ends_at.blank?

      if starts_at >= ends_at
        errors.add(:ends_at, :must_be_after_starts_at)
      end
    end

    def within_date_range?(date)
      return false if starts_at.present? && date < starts_at
      return false if ends_at.present? && date > ends_at

      true
    end
  end
end
