module Spree
  class Promotion < Spree.base_class
    include Spree::MultiStoreResource
    include Spree::Metadata
    if defined?(Spree::Webhooks::HasWebhooks)
      include Spree::Webhooks::HasWebhooks
    end
    if defined?(Spree::Security::Promotions)
      include Spree::Security::Promotions
    end

    MATCH_POLICIES = %w(all any)
    UNACTIVATABLE_ORDER_STATES = ['complete', 'awaiting_return', 'returned']

    attr_reader :eligibility_errors, :generate_code

    #
    # Magic methods
    #
    auto_strip_attributes :code, :path, :name

    #
    # Enums
    #
    enum :kind, { coupon_code: 0, automatic: 1 }

    #
    # Associations
    #
    belongs_to :promotion_category, optional: true
    has_many :promotion_rules, autosave: true, dependent: :destroy
    alias rules promotion_rules
    has_many :promotion_actions, autosave: true, dependent: :destroy
    alias actions promotion_actions
    has_many :coupon_codes, -> { order(created_at: :asc) }, dependent: :destroy, class_name: 'Spree::CouponCode'
    has_many :order_promotions, class_name: 'Spree::OrderPromotion'
    has_many :orders, through: :order_promotions, class_name: 'Spree::Order'
    has_many :store_promotions, class_name: 'Spree::StorePromotion'
    has_many :stores, class_name: 'Spree::Store', through: :store_promotions
    accepts_nested_attributes_for :promotion_actions, :promotion_rules

    #
    # Callbacks
    #
    before_validation :set_code_to_nil, if: -> { multi_codes? || automatic? }
    before_validation :set_number_of_codes_to_nil, if: -> { automatic? || !multi_codes? }
    before_validation :set_usage_limit_to_nil, if: -> { multi_codes? }
    before_validation :set_kind
    before_validation :downcase_code, if: -> { code.present? }
    before_validation :set_starts_at_to_current_time, if: -> { starts_at.blank? }
    after_commit :generate_coupon_codes, if: -> { multi_codes? }, on: [:create, :update]
    after_commit :remove_coupons, on: :update
    before_destroy :not_used?

    #
    # Validations
    #
    validates_associated :rules
    validates :name, presence: true
    validates :usage_limit, numericality: { greater_than: 0, allow_nil: true }
    validates :description, length: { maximum: 255 }, allow_blank: true
    validate :expires_at_must_be_later_than_starts_at, if: -> { starts_at && expires_at }
    validates :code, presence: true, if: -> { coupon_code? && !multi_codes? }
    validates :number_of_codes, numericality: {
      only_integer: true,
      greater_than: 0,
      less_than_or_equal_to: Spree::Config.coupon_codes_total_limit
    }, if: -> { multi_codes? }

    #
    # Scopes
    #
    scope :expired, -> { where('expires_at < ?', Time.current) }
    scope :coupons, -> { where(kind: :coupon_code) }
    scope :advertised, -> { where(advertise: true) }
    scope :applied, lambda {
      joins(<<-SQL).distinct
        INNER JOIN spree_order_promotions
        ON spree_order_promotions.promotion_id = #{table_name}.id
      SQL
    }

    #
    # Ransack
    #
    self.whitelisted_ransackable_attributes = ['path', 'promotion_category_id', 'code', 'starts_at', 'expires_at']
    self.whitelisted_ransackable_associations = %w[coupon_codes]

    def self.with_coupon_code(coupon_code)
      return nil unless coupon_code.present?

      coupon_code = coupon_code.strip.downcase

      coupons.includes(:promotion_actions).
        where.not(spree_promotion_actions: { id: nil }).
        where(code: coupon_code).or(
          where(id: Spree::CouponCode.where(code: coupon_code).select(:promotion_id))
        ).last
    end

    def self.active
      where('spree_promotions.starts_at IS NULL OR spree_promotions.starts_at < ?', Time.current).
        where('spree_promotions.expires_at IS NULL OR spree_promotions.expires_at > ?', Time.current)
    end

    def self.order_activatable?(order)
      order && !UNACTIVATABLE_ORDER_STATES.include?(order.state)
    end

    def generate_code=(generating_code)
      if ActiveModel::Type::Boolean.new.cast(generating_code)
        self.code = random_code
      end
    end

    def active?
      starts_at.present? && starts_at < Time.current && (expires_at.blank? || !expired?)
    end

    def inactive?
      !active?
    end

    def expired?
      !!(starts_at && Time.current < starts_at || expires_at && Time.current > expires_at)
    end

    def all_codes_used?
      coupon_codes.used.count == coupon_codes.count
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
        order.promotions << self unless order.promotions.include?(self)
        order.save
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
        order.promotions << self unless order.promotions.include?(self)
        order.save
      end

      action_taken
    end

    # called anytime order.update_with_updater! happens
    def eligible?(promotable, options = {})
      return false if expired? || usage_limit_exceeded?(promotable) || blacklisted?(promotable)

      !!eligible_rules(promotable, options)
    end

    # eligible_rules returns an array of promotion rules where eligible? is true for the promotable
    # if there are no such rules, an empty array is returned
    # if the rules make this promotable ineligible, then nil is returned (i.e. this promotable is not eligible)
    def eligible_rules(promotable, options = {})
      # Promotions without rules are eligible by default.
      return [] if rules.to_a.none? # preloaded rules as we're going to use them anyway, so avoiding additional database queries

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

    def usage_limit_exceeded?(promotable)
      usage_limit.present? && usage_limit > 0 && adjusted_credits_count(promotable) >= usage_limit
    end

    def adjusted_credits_count(promotable)
      adjustments = promotable.is_a?(Order) ? promotable.all_adjustments : promotable.adjustments
      credits_count - adjustments.promotion.where(source_id: actions.pluck(:id)).size
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
      user.orders.complete.joins(:promotions).joins(:all_adjustments).
        where.not(spree_orders: { id: excluded_orders.map(&:id) }).
        where(spree_promotions: { id: id }).
        where(spree_adjustments: { source_type: 'Spree::PromotionAction', eligible: true }).any?
    end

    def name_for_order(order)
      if coupon_code?
        code_for_order(order)
      else
        name
      end.to_s.upcase
    end

    def code_for_order(order)
      if multi_codes?
        coupon_codes.find_by(order: order)&.code
      else
        code
      end
    end

    private

    def not_used?
      return true if orders.empty?

      errors.add(:base, Spree.t('promotion_already_used'))
      throw(:abort)
    end

    def set_kind
      if (code.present? || (multi_codes? && number_of_codes.present?)) && kind == 'automatic'
        self.kind = :coupon_code
      end
    end

    def downcase_code
      self.code = code.downcase.strip
    end

    def set_code_to_nil
      self.code = nil
    end

    def set_usage_limit_to_nil
      self.usage_limit = nil
    end

    def set_number_of_codes_to_nil
      self.number_of_codes = nil
      self.code_prefix = nil
      self.multi_codes = false
    end

    def set_starts_at_to_current_time
      self.starts_at = Time.current
    end

    def generate_coupon_codes
      return if number_of_codes.nil?
      return if number_of_codes <= coupon_codes.count
      return unless saved_change_to_number_of_codes?

      if number_of_codes > Spree::Config.coupon_codes_web_limit
        Spree::CouponCodes::BulkGenerateJob.perform_later(id, number_of_codes - coupon_codes.count)
      else
        Spree::CouponCodes::BulkGenerate.call(promotion: self, quantity: number_of_codes - coupon_codes.count)
      end
    end

    def remove_coupons
      return unless (previous_changes.key?('kind') && previous_changes['kind'][0] == 'coupon_code' && kind == 'automatic') ||
                    (previous_changes.key?('multi_codes') && previous_changes['multi_codes'][0] == true && multi_codes == false)

      coupon_codes.where(deleted_at: nil).update_all(deleted_at: Time.current)
    end

    def blacklisted?(promotable)
      case promotable
      when Spree::LineItem
        !promotable.product.promotionable?
      when Spree::Order
        (promotable.item_count.positive? || promotion.line_items.any?) &&
          promotable.line_items.joins(:product).where(spree_products: { promotionable: true }).none?
      end
    end

    def match_all?
      match_policy == 'all'
    end

    def expires_at_must_be_later_than_starts_at
      errors.add(:expires_at, :invalid_date_range) if expires_at < starts_at
    end

    def random_code
      coupon_code = loop do
        random_token = SecureRandom.hex(4)
        break random_token unless self.class.exists?(code: random_token)
      end
      coupon_code
    end
  end
end
