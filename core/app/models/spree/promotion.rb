module Spree
  class Promotion < Spree::Base
    MATCH_POLICIES = %w(all any)
    UNACTIVATABLE_ORDER_STATES = ["awaiting_return", "returned"]
    BACKEND_PROMOTIONS = ["backend"]

    attr_reader :eligibility_errors

    belongs_to :promotion_category

    has_many :promotion_rules, autosave: true, dependent: :destroy
    alias_method :rules, :promotion_rules

    has_many :promotion_actions, autosave: true, dependent: :destroy
    alias_method :actions, :promotion_actions

    has_many :promotion_codes, dependent: :destroy
    alias_method :codes, :promotion_codes

    has_and_belongs_to_many :orders, join_table: 'spree_orders_promotions'

    accepts_nested_attributes_for :promotion_actions, :promotion_rules
    accepts_nested_attributes_for :promotion_codes, allow_destroy: true

    validates_associated :rules
    validates_associated :promotion_codes

    validates :name, presence: true
    validates :path, uniqueness: { allow_blank: true }
    validates :usage_limit, numericality: { greater_than: 0, allow_nil: true }
    validates :description, length: { maximum: 255 }

    before_save :normalize_blank_values

    order_join_table = reflect_on_association(:orders).join_table
    scope :applied, -> do
      joins("INNER JOIN #{order_join_table} ON " \
        "#{order_join_table}.promotion_id = #{table_name}.id").distinct
    end
    scope :coupons, -> do
      joins(:promotion_codes).where("#{Spree::PromotionCode.table_name}.value IS NOT NULL")
    end
    scope :backend, -> do
      joins(:promotion_category).where("#{Spree::PromotionCategory.table_name}.code IN (?)", BACKEND_PROMOTIONS)
    end

    def self.advertised
      where(advertise: true)
    end

    def self.with_coupon_code(coupon_code)
      joins(:promotion_codes).where(
        "lower(#{Spree::PromotionCode.table_name}.value) = ?", coupon_code.strip.downcase
      ).first
    end

    def self.active
      where("#{Spree::Promotion.table_name}.starts_at IS NULL OR " \
        "#{Spree::Promotion.table_name}.starts_at < ? AND " \
        "#{Spree::Promotion.table_name}.expires_at IS NULL OR " \
        "#{Spree::Promotion.table_name}.expires_at > ?", Time.now, Time.now)
    end

    def self.order_activatable?(order)
      order && !UNACTIVATABLE_ORDER_STATES.include?(order.state)
    end

    def expired?(coupon_code = nil)
      promo_exp = !!(starts_at && Time.now < starts_at || expires_at && Time.now > expires_at)
      code      = codes.find_by_value(coupon_code) if coupon_code.present?

      if code.present?
        promo_exp || code.expired?
      else
        promo_exp
      end
    end

    def activate(payload)
      order = payload[:order]
      return unless self.class.order_activatable?(order)

      payload[:promotion] = self

      # Track results from actions to see if any action has been taken.
      # Actions should return nil/false if no action has been taken.
      # If an action returns true, then an action has been taken.
      results = actions.map do |action|
        action.perform(payload)
      end
      # If an action has been taken, report back to whatever activated this promotion.
      action_taken = results.include?(true)

      if action_taken
      # connect to the order
      # create the join_table entry.
        self.orders << order
        self.save
      end

      return action_taken
    end

    # Failsafe - backwards compatibility
    def code
      codes.first.try(:value)
    end

    # Failsafe - backwards compatibility
    def code=(value)
      codes.build(value: value) unless value.blank?
    end

    # called anytime order.update! happens
    def eligible?(promotable, coupon_code = nil)
      return false if expired?(coupon_code) ||
                        usage_limit_exceeded?(promotable, coupon_code) ||
                        blacklisted?(promotable)
      !!eligible_rules(promotable, {})
    end

    # eligible_rules returns an array of promotion rules where eligible? is true for the promotable
    # if there are no such rules, an empty array is returned
    # if the rules make this promotable ineligible, then nil is returned (i.e. this promotable is not eligible)
    def eligible_rules(promotable, options = {})
      # Promotions without rules are eligible by default.
      return [] if rules.none?
      eligible = lambda { |r| r.eligible?(promotable, options) }
      specific_rules = rules.for(promotable)
      return [] if specific_rules.none?

      if match_all?
        # If there are rules for this promotion, but no rules for this
        # particular promotable, then the promotion is ineligible by default.
        unless specific_rules.all?(&eligible)
          @eligibility_errors = specific_rules.map(&:eligibility_errors).detect(&:present?)
          return nil
        end
        specific_rules
      else
        unless specific_rules.any?(&eligible)
          @eligibility_errors = specific_rules.map(&:eligibility_errors).detect(&:present?)
          return nil
        end
        specific_rules.select(&eligible)
      end
    end

    def products
      rules.where(type: "Spree::Promotion::Rules::Product").map(&:products).flatten.uniq
    end

    def usage_limit_exceeded?(promotable, coupon_code = nil)
      promo_exc = usage_limit.to_i > 0 && adjusted_credits_count(promotable) >= usage_limit
      code      = codes.find_by_value(coupon_code) if coupon_code.present?

      if code.present?
        promo_exc && code.usage_limit_exceeded?
      else
        promo_exc
      end
    end

    def adjusted_credits_count(promotable)
      credits_count - promotable.adjustments.promotion.where(:source_id => actions.pluck(:id)).count
    end

    def credits
      Adjustment.eligible.promotion.where(source_id: actions.map(&:id))
    end

    def credits_count
      credits.count
    end

    def line_item_actionable?(order, line_item)
      if eligible? order
        rules = eligible_rules(order)
        if rules.blank?
          true
        else
          rules.send(match_all? ? :all? : :any?) do |rule|
            rule.actionable? line_item
          end
        end
      else
        false
      end
    end

    def used_by?(user, excluded_orders = [])
      [
        :adjustments,
        :line_item_adjustments,
        :shipment_adjustments
      ].any? do |adjustment_type|
        user.orders.complete.joins(adjustment_type).where(
          spree_adjustments: {
            source_type: 'Spree::PromotionAction',
            source_id: actions.map(&:id),
            eligible: true
          }
        ).where.not(
          id: excluded_orders.map(&:id)
        ).any?
      end
    end

    private
    def blacklisted?(promotable)
      case promotable
      when Spree::LineItem
        !promotable.product.promotionable?
      when Spree::Order
        promotable.line_items.any? &&
          !promotable.line_items.joins(:product).where(spree_products: {promotionable: true}).any?
      end
    end

    def normalize_blank_values
      self[:path] = nil if self[:path].blank?
    end

    def match_all?
      match_policy == 'all'
    end
  end
end
