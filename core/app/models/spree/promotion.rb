module Spree
  class Promotion < Spree::Base
    MATCH_POLICIES = %w(all any)
    UNACTIVATABLE_ORDER_STATES = ['complete', 'awaiting_return', 'returned']
    DEFAULT_RANDOM_CODE_LENGTH = 6

    attr_reader :eligibility_errors

    belongs_to :promotion_category, optional: true

    has_many :promotion_rules, autosave: true, dependent: :destroy
    alias rules promotion_rules

    has_many :promotion_actions, autosave: true, dependent: :destroy
    alias actions promotion_actions

    has_many :order_promotions, class_name: 'Spree::OrderPromotion'
    has_many :orders, through: :order_promotions, class_name: 'Spree::Order'

    has_many :codes, class_name: 'Spree::PromotionCode', inverse_of: :promotion
    alias_method :promotion_codes, :codes

    accepts_nested_attributes_for :promotion_actions, :promotion_rules

    validates_associated :rules

    validates :name, presence: true
    validates :path, :code, uniqueness: { case_sensitive: false, allow_blank: true }
    validates :usage_limit, numericality: { greater_than: 0, allow_nil: true }
    validates :per_code_usage_limit, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
    validates :description, length: { maximum: 255 }, allow_blank: true
    validate :expires_at_must_be_later_than_starts_at, if: -> { starts_at && expires_at }

    before_save :normalize_blank_values

    scope :coupons, -> { where.not(code: nil) }
    scope :advertised, -> { where(advertise: true) }
    scope :applied, lambda {
      joins(<<-SQL).distinct
        INNER JOIN spree_order_promotions
        ON spree_order_promotions.promotion_id = #{table_name}.id
      SQL
    }

    self.whitelisted_ransackable_attributes = ['path', 'promotion_category_id', 'code']

    def self.with_coupon_code(coupon_code)
      where("lower(#{table_name}.code) = ?", coupon_code.strip.downcase).
        includes(:promotion_actions).where.not(spree_promotion_actions: { id: nil }).
        first
    end
    # temporary code. remove after the column is dropped from the db.
    def columns
      super.reject { |column| column.name == 'code' }
    end

    def self.advertised
      where(advertise: true)
    end

    def self.active
      where('spree_promotions.starts_at IS NULL OR spree_promotions.starts_at < ?', Time.current).
        where('spree_promotions.expires_at IS NULL OR spree_promotions.expires_at > ?', Time.current)
    end

    def self.order_activatable?(order)
      order && !UNACTIVATABLE_ORDER_STATES.include?(order.state)
    end

    def code
      fail 'Attempted to call code on a Spree::Promotion. Promotions are now tied to multiple code records'
    end

    def code=(val)
      fail 'Attempted to call code= on a Spree::Promotion. Promotions are now tied to multiple code records'
    end

    def as_json(options={})
      options[:except] ||= :code
      super
    end

    def self.with_coupon_code(val)
      if code = PromotionCode.where(value: val.downcase).first
        code.promotion
      end
    end

    def expired?
      !active?
    end

    def active?
      (starts_at.nil? || starts_at < Time.now) && (expires_at.nil? || expires_at > Time.now)
    end

    def activate(order:, line_item: nil, user: nil, path: nil, promotion_code: nil)
      return unless self.class.order_activatable?(order)

      payload = {
        order: order,
        promotion: self,
        line_item: line_item,
        user: user,
        path: path,
        promotion_code: promotion_code
      }

      # Track results from actions to see if any action has been taken.
      # Actions should return nil/false if no action has been taken.
      # If an action returns true, then an action has been taken.
      results = actions.map do |action|
        action.perform(payload)
      end
      # If an action has been taken, report back to whatever activated this promotion.
      action_taken = results.include?(true)

      if action_taken
        # create the join_table entry.
        orders << order
        save
      end

      action_taken
    end

    # Called when a promotion is removed from the cart
    def deactivate(payload)
      order = payload[:order]
      return unless self.class.order_activatable?(order)

      payload[:promotion] = self

      # Track results from actions to see if any action has been taken.
      # Actions should return nil/false if no action has been taken.
      # If an action returns true, then an action has been taken.
      results = actions.map do |action|
        action.revert(payload) if action.respond_to?(:revert)
      end

      # If an action has been taken, report back to whatever `d this promotion.
      action_taken = results.include?(true)

      if action_taken
        # connect to the order
        # create the join_table entry.
        orders << order
        save
        order_promotions.find_or_create_by!(order_id: order.id, promotion_code_id: promotion_code.try!(:id))
      end

      action_taken
    end

    # called anytime order.update! happens
    def eligible?(promotable, promotion_code: nil)
      return false if expired?
      return false if usage_limit_exceeded?(promotable)
      return false if promotion_code && promotion_code.usage_limit_exceeded?(promotable)
      return false if blacklisted?(promotable)
      !!eligible_rules(promotable, {})
    end

    # eligible_rules returns an array of promotion rules where eligible? is true for the promotable
    # if there are no such rules, an empty array is returned
    # if the rules make this promotable ineligible, then nil is returned (i.e. this promotable is not eligible)
    def eligible_rules(promotable, options = {})
      # Promotions without rules are eligible by default.
      return [] if rules.none?
      eligible = ->(r) { r.eligible?(promotable, options) }
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
      rules.where(type: 'Spree::Promotion::Rules::Product').map(&:products).flatten.uniq
    end

    # Whether the given promotable would violate the usage restrictions
    #
    # @param promotable object (e.g. order/line item/shipment)
    # @return true or false
    def usage_limit_exceeded?(promotable)
      # TODO: This logic appears to be wrong.
      # Currently if you have:
      # - 2 different line item level actions on a promotion
      # - 2 line items in an order
      # Then using the promo on that order will create 4 adjustments and count as 4
      # usages.
      # See also PromotionCode#usage_limit_exceeded?
      if usage_limit
        usage_count - usage_count_for(promotable) >= usage_limit
      end
    end

    # Number of times the code has been used overall
    #
    # @return [Integer] usage count
    def usage_count
      adjustment_promotion_scope(Spree::Adjustment.eligible).count
    end

    # Number of times the code has been used for the given promotable
    #
    # @param promotable promotable object (e.g. order/line item/shipment)
    # @return [Integer] usage count for this promotable
    # TODO: specs
    def usage_count_for(promotable)
      adjustment_promotion_scope(promotable.adjustments).count
    end

    # TODO: specs
    def line_item_actionable?(order, line_item, promotion_code: nil)
      if eligible?(order, promotion_code: promotion_code)
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

    # Build promo codes. If number_of_codes is great than one then generate
    # multiple codes by adding a random suffix to each code.
    #
    # @param base_code [String] When number_of_codes=1 this is the code. When
    #   number_of_codes > 1 it is the base of the generated codes.
    # @param number_of_codes [Integer] Number of codes to generate
    # @param usage_limit [Integer] Usage limit for each code
    def build_promotion_codes(base_code:, number_of_codes:)
      if number_of_codes == 1
        codes.build(value: base_code)
      elsif number_of_codes > 1
        number_of_codes.times do
          build_code_with_base(base_code: base_code)
        end
      end
    end

    private

    def blacklisted?(promotable)
      case promotable
      when Spree::LineItem
        !promotable.product.promotionable?
      when Spree::Order
        promotable.line_items.any? &&
          promotable.line_items.joins(:product).where(spree_products: { promotionable: true }).none?
      end
    end

    def adjustment_promotion_scope(adjustment_scope)
      adjustment_scope.promotion.where(source_id: actions.map(&:id))
    end

    def normalize_blank_values
      self[:path] = nil if self[:path].blank?
    end

    def match_all?
      match_policy == 'all'
    end

    def expires_at_must_be_later_than_starts_at
      errors.add(:expires_at, :invalid_date_range) if expires_at < starts_at
    end

    def build_code_with_base(base_code:)
      random_code = code_with_randomness(base_code: base_code)

      if Spree::PromotionCode.where(value: random_code).exists? || codes.any? { |c| c.value == random_code }
        build_code_with_base(base_code: base_code)
      else
        codes.build(value: random_code)
      end
    end

    def code_with_randomness(base_code:)
      "#{base_code}_#{Array.new(DEFAULT_RANDOM_CODE_LENGTH){ ('A'..'Z').to_a.sample }.join}"
    end
  end
end
