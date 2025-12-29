module Spree
  class PriceList < Spree::Base
    acts_as_paranoid
    acts_as_list scope: :store

    MATCH_POLICIES = %w[all any].freeze

    belongs_to :store, class_name: 'Spree::Store'

    has_many :price_rules, class_name: 'Spree::PriceRule', dependent: :destroy
    has_many :prices, class_name: 'Spree::Price', dependent: :destroy_async

    validates :name, :store, presence: true
    validates :match_policy, presence: true, inclusion: { in: MATCH_POLICIES }
    validate :starts_at_before_ends_at

    scope :by_position, -> { order(position: :asc) }
    scope :for_store, ->(store) { where(store: store) }
    scope :current, lambda { |timezone = nil|
      timezone ||= Rails.application.config.time_zone
      current_time = Time.current.in_time_zone(timezone)
      where('starts_at IS NULL OR starts_at <= ?', current_time)
        .where('ends_at IS NULL OR ends_at >= ?', current_time)
    }

    state_machine :status, initial: :inactive do
      event :activate do
        transition to: :active
      end

      event :deactivate do
        transition to: :inactive
      end

      event :schedule do
        transition to: :scheduled
      end
    end

    def self.for_context(context)
      timezone = context.store&.preferred_timezone || 'UTC'
      for_store(context.store)
        .with_status(:active)
        .current(timezone)
        .by_position
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
