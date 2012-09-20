module Spree
  class Promotion < Spree::Activator
    MATCH_POLICIES = %w(all any)
    UNACTIVATABLE_ORDER_STATES = ["complete", "awaiting_return", "returned"]

    Activator.event_names << 'spree.checkout.coupon_code_added'
    Activator.event_names << 'spree.content.visited'

    has_many :promotion_rules, :foreign_key => :activator_id, :autosave => true, :dependent => :destroy
    alias_method :rules, :promotion_rules
    accepts_nested_attributes_for :promotion_rules

    has_many :promotion_actions, :foreign_key => :activator_id, :autosave => true, :dependent => :destroy
    alias_method :actions, :promotion_actions
    accepts_nested_attributes_for :promotion_actions

    validates_associated :rules

    attr_accessible :name, :event_name, :code, :match_policy,
                    :path, :advertise, :description, :usage_limit,
                    :starts_at, :expires_at, :promotion_rules_attributes,
                    :promotion_actions_attributes

    # TODO: This shouldn't be necessary with :autosave option but nested attribute updating of actions is broken without it
    after_save :save_rules_and_actions
    def save_rules_and_actions
      (rules + actions).each &:save
    end

    validates :name, :presence => true
    validates :code, :presence => true, :if => lambda{|r| r.event_name == 'spree.checkout.coupon_code_added' }
    validates :path, :presence => true, :if => lambda{|r| r.event_name == 'spree.content.visited' }
    validates :usage_limit, :numericality => { :greater_than => 0, :allow_nil => true }

    def self.advertised
      where(:advertise => true)
    end

    def self.with_coupon_code(coupon_code)
      search(:code_cont => coupon_code).result
    end

    def self.handle_notifications(*args)
      event_name, start_time, end_time, id, payload = args
      payload[:event_name] = event_name

      if payload[:order].present?
        payload[:order].adjustments.promotion.each do |adjustment|
          adjustment.delete if adjustment.originator.promotion.event_name == event_name
        end
        
        payload[:order].update!
      end

      self.active.event_name_starts_with(event_name).each do |activator|
        activator.activate(payload)
      end
    end

    def activate(payload)
      return unless order_activatable? payload[:order]

      if code.present?
        event_code = payload[:coupon_code].to_s.strip.downcase
        return unless event_code == self.code.to_s.strip.downcase
      end

      if path.present?
        return unless path == payload[:path]
      end

      actions.each do |action|
        action.perform(payload)
      end
    end

    # called anytime order.update! happens via Spree::Adjustment#eligible_for_originator?
    def eligible?(order)
      return false if expired? || usage_limit_exceeded?(order)
      rules_are_eligible?(order, {})
    end

    def rules_are_eligible?(order, options = {})
      return true if rules.none?
      eligible = lambda { |r| r.eligible?(order, options) }
      if match_policy == 'all'
        rules.all?(&eligible)
      else
        rules.any?(&eligible)
      end
    end

    def order_activatable?(order)
      order &&
      !UNACTIVATABLE_ORDER_STATES.include?(order.state)
    end

    # Products assigned to all product rules
    def products
      @products ||= rules.of_type('Spree::Promotion::Rules::Product').map(&:products).flatten.uniq
    end

    def usage_limit_exceeded?(order = nil)
      usage_limit.present? && usage_limit > 0 && adjusted_credits_count(order) >= usage_limit
    end

    def adjusted_credits_count(order)
      return credits_count if order.nil?
      credits_count - (order.promotion_credit_exists?(self) ? 1 : 0)
    end

    def credits
      Adjustment.promotion.where(:originator_id => actions.map(&:id))
    end

    def credits_count
      credits.count
    end

  end
end
