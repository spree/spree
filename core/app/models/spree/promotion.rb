module Spree
  class Promotion < Spree::Base
    MATCH_POLICIES = %w(all any)
    UNACTIVATABLE_ORDER_STATES = ["complete", "awaiting_return", "returned"]

    has_many :promotion_rules, autosave: true, dependent: :destroy
    alias_method :rules, :promotion_rules

    has_many :promotion_actions, autosave: true, dependent: :destroy
    alias_method :actions, :promotion_actions

    has_and_belongs_to_many :orders, join_table: 'spree_orders_promotions'

    accepts_nested_attributes_for :promotion_actions, :promotion_rules

    validates_associated :rules

    validates :name, presence: true
    validates :path, uniqueness: true, allow_blank: true
    validates :usage_limit, numericality: { greater_than: 0, allow_nil: true }
    validates :description, length: { maximum: 255 }

    before_save :normalize_blank_values

    def self.advertised
      where(advertise: true)
    end

    def self.with_coupon_code(coupon_code)
      where("lower(code) = ?", coupon_code.strip.downcase).first
    end

    def self.active
      where('starts_at IS NULL OR starts_at < ?', Time.now).
        where('expires_at IS NULL OR expires_at > ?', Time.now)
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
      return false if expired? || usage_limit_exceeded?(promotable)
      rules_are_eligible?(promotable, {})
    end

    def rules_are_eligible?(promotable, options = {})
      # Promotions without rules are eligible by default.
      return true if rules.none?
      eligible = lambda { |r| r.eligible?(promotable, options) }
      specific_rules = rules.for(promotable)
      return true if specific_rules.none?
      if match_policy == 'all'
        # If there are rules for this promotion, but no rules for this
        # particular promotable, then the promotion is ineligible by default.
        specific_rules.any? && specific_rules.all?(&eligible)
      else
        # If there are no rules for this promotable, then this will return false.
        # If there are rules for this promotable, but they are ineligible, this will return false.
        specific_rules.any?(&eligible)
      end
    end

    # Products assigned to all product rules
    def products
      @products ||= self.rules.to_a.inject([]) do |products, rule|
        rule.respond_to?(:products) ? products << rule.products : products
      end.flatten.uniq
    end

    def product_ids
      products.map(&:id)
    end

    def usage_limit_exceeded?(promotable)
      usage_limit.present? && usage_limit > 0 && adjusted_credits_count(promotable) >= usage_limit
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

    private
    def normalize_blank_values
      [:code, :path].each do |column|
        self[column] = nil if self[column].blank?
      end
    end
  end
end
