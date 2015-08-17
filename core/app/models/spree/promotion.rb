module Spree
  class Promotion < Spree::Base
    MATCH_POLICIES = %w(all any)
    UNACTIVATABLE_ORDER_STATES = ["complete", "awaiting_return", "returned"]

    attr_reader :eligibility_errors

    belongs_to :promotion_category

    has_many :promotion_rules, autosave: true, dependent: :destroy
    alias_method :rules, :promotion_rules

    has_many :promotion_actions, autosave: true, dependent: :destroy
    alias_method :actions, :promotion_actions

    has_and_belongs_to_many :orders, join_table: 'spree_orders_promotions'

    accepts_nested_attributes_for :promotion_actions, :promotion_rules

    validates_associated :rules

    validates :name, presence: true
    validates :path, uniqueness: { allow_blank: true }
    validates :usage_limit, numericality: { greater_than: 0, allow_nil: true }
    validates :description, length: { maximum: 255 }

    before_save :normalize_blank_values

    scope :coupons, ->{ where("#{table_name}.code IS NOT NULL") }

    order_join_table = reflect_on_association(:orders).join_table

    scope :applied, -> { joins("INNER JOIN #{order_join_table} ON #{order_join_table}.promotion_id = #{table_name}.id").uniq }

    self.whitelisted_ransackable_attributes = ['code', 'path', 'promotion_category_id']

    def self.advertised
      where(advertise: true)
    end

    def self.with_coupon_code(coupon_code)
      where("lower(#{self.table_name}.code) = ?", coupon_code.strip.downcase).first
    end

    def self.active
      where('spree_promotions.starts_at IS NULL OR spree_promotions.starts_at < ?', Time.now).
        where('spree_promotions.expires_at IS NULL OR spree_promotions.expires_at > ?', Time.now)
    end

    def self.order_activatable?(order)
      order && !UNACTIVATABLE_ORDER_STATES.include?(order.state)
    end

    def expired?
      !!(starts_at && Time.now < starts_at || expires_at && Time.now > expires_at)
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

    # called anytime order.update! happens
    def eligible?(promotable)
      return false if expired? || usage_limit_exceeded?(promotable) || blacklisted?(promotable)
      !!eligible_rules(promotable, {})
    end

    # eligible_rules returns an array of promotion rules where eligible? is true for the promotable
    # if there are no such rules, an empty array is returned
    # if the rules make this promotable ineligible, then nil is returned (i.e. this promotable is not eligible)
    def eligible_rules(promotable, options = {})
      # Promotions without rules are eligible by default.
      return [] if rules.none?
      eligible = lambda { |r| r.eligible?(promotable, options) }
      specific_rules = rules.select { |rule| rule.applicable?(promotable) }
      return [] if specific_rules.none?

      rule_eligibility = Hash[specific_rules.map do |rule|
        [rule, rule.eligible?(promotable, options)]
      end]

      if match_all?
        # If there are rules for this promotion, but no rules for this
        # particular promotable, then the promotion is ineligible by default.
        unless rule_eligibility.values.all?
          @eligibility_errors = specific_rules.map(&:eligibility_errors).detect(&:present?)
          return nil
        end
        specific_rules
      else
        unless rule_eligibility.values.any?
          @eligibility_errors = specific_rules.map(&:eligibility_errors).detect(&:present?)
          return nil
        end

        [rule_eligibility.detect { |_, eligibility| eligibility }.first]
      end
    end

    def products
      rules.where(type: "Spree::Promotion::Rules::Product").map(&:products).flatten.uniq
    end

    def usage_limit_exceeded?(promotable)
      usage_limit.present? && usage_limit > 0 && adjusted_credits_count(promotable) >= usage_limit
    end

    def adjusted_credits_count(promotable)
      adjustments = promotable.is_a?(Order) ? promotable.all_adjustments : promotable.adjustments
      credits_count - adjustments.promotion.where(:source_id => actions.pluck(:id)).count
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
      [:code, :path].each do |column|
        self[column] = nil if self[column].blank?
      end
    end

    def match_all?
      match_policy == 'all'
    end
  end
end
