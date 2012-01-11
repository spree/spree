module Spree
  class Promotion < Spree::Activator
    MATCH_POLICIES = %w(all any)

    preference :usage_limit, :integer
    preference :match_policy, :string, :default => MATCH_POLICIES.first
    preference :code, :string
    preference :advertise, :boolean, :default => false

    [:usage_limit, :match_policy, :code, :advertise].each do |field|
      alias_method field, "preferred_#{field}"
      alias_method "#{field}=", "preferred_#{field}="
    end

    has_many :promotion_rules, :foreign_key => 'activator_id', :autosave => true, :dependent => :destroy
    alias_method :rules, :promotion_rules
    accepts_nested_attributes_for :promotion_rules

    has_many :promotion_actions, :foreign_key => 'activator_id', :autosave => true, :dependent => :destroy
    alias_method :actions, :promotion_actions
    accepts_nested_attributes_for :promotion_actions

    after_create :update_preferences

    # TODO: This shouldn't be necessary with :autosave option but nested attribute updating of actions is broken without it
    after_save :save_rules_and_actions
    def save_rules_and_actions
      (rules + actions).each &:save
    end

    validates :name, :presence => true
    #validates :preferred_code, :presence => true, :if => lambda{|r| r.event_name == 'spree.checkout.coupon_code_added' }

    %w(usage_limit match_policy code advertise).each do |pref|
      method_name = pref.to_sym
      define_method method_name do
        get_preference(pref.to_sym)
      end

      method_name = "#{pref}=".to_sym
      define_method method_name do |value|
        unless new_record?
          pref = value
        else
          @preferences_hash ||= {}
          @preferences_hash[pref.to_sym] = value
        end
      end
    end

    class << self
      def advertised
        #TODO this is broken because the new preferences aren't a direct relationship returning
        #all for now
        scoped
        #includes(:stored_preferences)
        #includes(:stored_preferences).where(:spree_preferences => {:name => 'advertise', :value => '1'})
      end
    end

    # TODO: Remove that after fix for https://rails.lighthouseapp.com/projects/8994/tickets/4329-has_many-through-association-does-not-link-models-on-association-save
    # is provided
    def save(*)
      if super
        promotion_rules.each { |p| p.save }
      end
    end

    def activate(payload)
      # Since multiple promotions could be listening we need to make sure the
      # event applies to this one.
      if eligible?(payload[:order], payload)
        actions.each do |action|
          action.perform(payload)
        end
      end
    end

    # Whether the promotion is eligible for this particular order.
    def eligible?(order, options = {})
      return false if expired? || usage_limit_exceeded?(order)

      event_code = options[:coupon_code].to_s.strip.downcase
      return false unless event_code == self.code.to_s.strip.downcase

      rules_are_eligible?(order, options)
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

    # Products assigned to all product rules
    def products
      @products ||= rules.of_type('Promotion::Rules::Product').map(&:products).flatten.uniq
    end

    def usage_limit_exceeded?(order = nil)
      preferred_usage_limit.present? && preferred_usage_limit.to_i > 0 && adjusted_credits_count(order) >= preferred_usage_limit.to_i
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


    private

    def update_preferences
      if @preferences_hash.present? && !@preferences_hash.empty?
        @preferences_hash.each do |key, value|
          pref_key = "spree/promotion/#{key}/#{self.id}"
          Spree::Preference.create(:value => value, :key => pref_key)
        end
      end
    end
  end
end
