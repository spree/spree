module Spree
  class PriceList < Spree::Base
    acts_as_paranoid
    acts_as_list scope: :store

    include Spree::SingleStoreResource

    MATCH_POLICIES = %w[all any].freeze

    belongs_to :store, class_name: 'Spree::Store'

    has_many :price_rules, class_name: 'Spree::PriceRule', dependent: :destroy
    has_many :prices, class_name: 'Spree::Price', dependent: :destroy_async
    has_many :variants, -> { where(spree_prices: { deleted_at: nil }).distinct }, through: :prices, source: :variant
    has_many :products, -> { where(spree_prices: { deleted_at: nil }).distinct }, through: :variants, source: :product
    alias price_list_products products

    # Override default nested attributes to use bulk_update_prices for performance
    attr_reader :prices_attributes

    def prices_attributes=(attributes)
      @prices_attributes = attributes.values
    end

    after_update :process_bulk_prices_update

    def process_bulk_prices_update
      return if @prices_attributes.blank?

      bulk_update_prices(@prices_attributes)
      @prices_attributes = nil
    end

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

    state_machine :status, initial: :draft do
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

    # Returns price lists applicable for a given pricing context
    # - active: always applies (within date range)
    # - scheduled: applies only within starts_at/ends_at date range
    def self.for_context(context)
      timezone = context.store&.preferred_timezone || 'UTC'
      for_store(context.store)
        .with_status(:active, :scheduled)
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

    # Returns true if the price list is currently in effect
    # (active, or scheduled and within date range)
    def currently_active?
      active_or_scheduled? && within_date_range?(Time.current)
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

    # Bulk update prices using upsert_all for performance
    # @param prices_attributes [Array<Hash>] array of price attributes with :id, :amount, :compare_at_amount
    # @return [Boolean] true if successful
    def bulk_update_prices(prices_attributes)
      return true if prices_attributes.blank?

      records_to_upsert = []
      variant_ids = Set.new

      # Get current values for comparison
      price_ids = prices_attributes.map { |a| a[:id] || a['id'] }.compact.map(&:to_i)
      current_values = prices.where(id: price_ids).pluck(:id, :amount, :compare_at_amount).to_h { |id, amount, compare_at| [id, { amount: amount, compare_at_amount: compare_at }] }

      prices_attributes.each do |attrs|
        attrs = (attrs.respond_to?(:to_unsafe_h) ? attrs.to_unsafe_h : attrs.to_h).with_indifferent_access
        next if attrs[:id].blank?

        price_id = attrs[:id].to_i
        current = current_values[price_id] || {}

        # Parse amounts using LocalizedNumber for proper decimal handling
        amount = attrs[:amount].present? ? Spree::LocalizedNumber.parse(attrs[:amount]) : nil
        compare_at_amount = attrs[:compare_at_amount].present? ? Spree::LocalizedNumber.parse(attrs[:compare_at_amount]) : nil

        # Clear compare_at_amount if it equals amount
        compare_at_amount = nil if compare_at_amount == amount

        # Skip if nothing changed
        next if amount == current[:amount] && compare_at_amount == current[:compare_at_amount]

        records_to_upsert << {
          id: price_id,
          variant_id: attrs[:variant_id].to_i,
          currency: attrs[:currency],
          amount: amount,
          compare_at_amount: compare_at_amount,
          price_list_id: id
        }

        variant_ids << attrs[:variant_id].to_i
      end

      return true if records_to_upsert.empty?

      opts = { update_only: [:amount, :compare_at_amount] }
      opts[:unique_by] = :id unless ActiveRecord::Base.connection.adapter_name == 'Mysql2'

      Spree::Price.upsert_all(records_to_upsert, **opts)

      touch_variants(variant_ids.to_a)
      true
    end

    private

    def touch_variants(variant_ids)
      return if variant_ids.blank?

      Spree::Variants::TouchJob.perform_later(variant_ids)
    end

    def starts_at_before_ends_at
      return if starts_at.blank? || ends_at.blank?

      if starts_at >= ends_at
        errors.add(:ends_at, :must_be_after_starts_at)
      end
    end

    def within_date_range?(date)
      timezone = store&.preferred_timezone || Rails.application.config.time_zone
      date_in_tz = date.in_time_zone(timezone)

      return false if starts_at.present? && date_in_tz < starts_at
      return false if ends_at.present? && date_in_tz > ends_at

      true
    end
  end
end
