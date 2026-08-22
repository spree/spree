## Base class for all types of promotion action.
# PromotionActions perform the necessary tasks when a promotion is activated by an event and determined to be eligible.
module Spree
  class PromotionAction < Spree.base_class
    has_prefix_id :pact

    registers_subclasses_via { Spree.promotions.actions }

    acts_as_paranoid

    belongs_to :promotion, class_name: 'Spree::Promotion', touch: true

    validates :type, presence: true

    scope :of_type, ->(t) { where(type: t) }

    # This method should be overridden in subclass
    # Updates the state of the order or performs some other action depending on the subclass
    # options will contain the payload from the event that activated the promotion. This will include
    # the key :user which allows user based actions to be performed in addition to actions on the order
    def perform(_options = {})
      raise 'perform should be implemented in a sub-class of PromotionAction'
    end

    # Which competition group this action's discounts belong to
    # (+:line_item+, +:fulfillment+, +:order+), or nil for actions that don't
    # write Discount rows. Drives Spree::Adjusters::Promotion.
    #
    # @return [Symbol, nil]
    def discount_scope
      nil
    end

    # Whether this action's Discount rows persist at zero amount (only
    # FreeShipping — row existence is the signal).
    def persist_at_zero?
      false
    end

    # Returns true if the promotion action is a free shipping action
    #
    # @return [Boolean]
    def free_shipping?
      type.to_s.demodulize == 'FreeShipping'
    end

    # STI type names for a discount scope, covering both the 6.0 names and
    # the legacy names still present in the type column until the 6.1 data
    # migration.
    #
    # @param scope [Symbol] :line_item, :fulfillment or :order
    # @return [Array<String>]
    def self.types_for_discount_scope(scope)
      case scope
      when :line_item
        %w[Spree::Promotion::Actions::CreateItemAdjustments Spree::Promotion::Actions::CreateItemAdjustments]
      when :fulfillment
        %w[Spree::Promotion::Actions::FreeShipping Spree::Promotion::Actions::FreeShipping]
      when :order
        %w[Spree::Promotion::Actions::CreateAdjustment Spree::Promotion::Actions::CreateAdjustment]
      else
        []
      end
    end

    def self.human_name
      Spree.t("promotion_action_types.#{api_type}.name", default: api_type.titleize)
    end

    def self.human_description
      Spree.t("promotion_action_types.#{api_type}.description", default: '')
    end

    def human_name = self.class.human_name
    def human_description = self.class.human_description

    # Returns the key of the promotion action
    #
    # @return [String] eg. free_shipping
    def key
      self.class.api_type
    end

    protected

    # Shared perform for discount-writing actions: report whether this action
    # currently yields a candidate (that connects the promotion to the order,
    # so it keeps competing on later recalculations even if it loses now),
    # then settle rows immediately.
    def apply_via_adjuster(options)
      order = options[:order]
      promotion = options[:promotion] || self.promotion

      adjuster = Spree::Adjusters::Promotion.new(order, extra_promotions: [promotion])
      produced = adjuster.candidate_for?(self)
      adjuster.update if produced
      produced
    end

    def label
      Spree.t(:promotion_label, name: promotion.name)
    end
  end
end
