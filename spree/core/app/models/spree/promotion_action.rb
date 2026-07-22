## Base class for all types of promotion action.
# PromotionActions perform the necessary tasks when a promotion is activated by an event and determined to be eligible.
module Spree
  class PromotionAction < Spree.base_class
    has_prefix_id :pact

    acts_as_paranoid

    belongs_to :promotion, class_name: 'Spree::Promotion', touch: true

    has_many :discount_lines, class_name: 'Spree::DiscountLine', inverse_of: :promotion_action

    validates :promotion, :type, presence: true

    scope :of_type, ->(t) { where(type: t) }

    # Per-subclass permitted attributes beyond `type` and `preferences`.
    # Override in STI subclasses that accept nested attributes (e.g.
    # CreateLineItems needs `promotion_action_line_items_attributes`,
    # CreateAdjustment needs `calculator_type` + `calculator_attributes`).
    # The Admin API merges these into its `params.permit(...)` allowlist.
    def self.additional_permitted_attributes
      []
    end

    # This method should be overridden in subclass
    # Updates the state of the order or performs some other action depending on the subclass
    # options will contain the payload from the event that activated the promotion. This will include
    # the key :user which allows user based actions to be performed in addition to actions on the order
    def perform(_options = {})
      raise 'perform should be implemented in a sub-class of PromotionAction'
    end

    # Returns true if the promotion action is a free shipping action
    #
    # @return [Boolean]
    def free_shipping?
      type == 'Spree::Promotion::Actions::FreeShipping'
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

    def label
      Spree.t(:promotion_label, name: promotion.name)
    end
  end
end
