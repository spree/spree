module Spree
  class PriceList < Spree::Base
    acts_as_paranoid
    acts_as_list scope: :store

    include Spree::SingleStoreResource

    MATCH_POLICIES = %w[all any].freeze

    belongs_to :store, class_name: 'Spree::Store'

    has_many :price_rules, class_name: 'Spree::PriceRule', dependent: :destroy
    has_many :prices, class_name: 'Spree::Price', dependent: :destroy_async
    has_many :variants, -> { where(spree_prices: { deleted_at: nil }) }, through: :prices, source: :variant
    has_many :products, -> { where(spree_prices: { deleted_at: nil }) }, through: :variants, source: :product
    alias price_list_products products

    accepts_nested_attributes_for :prices,
                                  allow_destroy: true,
                                  reject_if: ->(attrs) { attrs['amount'].blank? && attrs['id'].blank? }

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

    def self.match_policies
      MATCH_POLICIES.map { |key| [Spree.t(key), key] }
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

    def add_products(product_ids)
      return if product_ids.blank?

      currencies = store.supported_currencies_list.map(&:iso_code)
      variant_ids = Spree::Variant.eligible.where(product_id: product_ids).distinct.pluck(:id)
      now = Time.current

      prices_to_insert = []

      currencies.each do |currency|
        existing_variant_ids = prices.where(currency: currency).pluck(:variant_id)
        new_variant_ids = variant_ids - existing_variant_ids

        new_variant_ids.each do |variant_id|
          prices_to_insert << {
            variant_id: variant_id,
            currency: currency,
            amount: nil,
            price_list_id: id,
            created_at: now,
            updated_at: now
          }
        end
      end

      if prices_to_insert.any?
        Spree::Price.insert_all(prices_to_insert)
        touch_variants(variant_ids)
      end
    end

    def remove_products(product_ids)
      return if product_ids.blank?

      variant_ids = Spree::Variant.where(product_id: product_ids).distinct.pluck(:id)
      prices.where(variant_id: variant_ids).delete_all
      touch_variants(variant_ids)
    end

    private

    def touch_variants(variant_ids)
      Spree::Variant.where(id: variant_ids).each(&:touch)
    end

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
