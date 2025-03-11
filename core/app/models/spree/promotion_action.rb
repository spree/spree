## Base class for all types of promotion action.
# PromotionActions perform the necessary tasks when a promotion is activated by an event and determined to be eligible.
module Spree
  class PromotionAction < Spree.base_class
    acts_as_paranoid

    belongs_to :promotion, class_name: 'Spree::Promotion'

    validates :promotion, :type, presence: true

    scope :of_type, ->(t) { where(type: t) }

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

    # Returns the human name of the promotion action
    #
    # @return [String] eg. Free Shipping
    def human_name
      Spree.t("promotion_action_types.#{key}.name")
    end

    # Returns the human description of the promotion action
    #
    # @return [String]
    def human_description
      Spree.t("promotion_action_types.#{key}.description")
    end

    # Returns the key of the promotion action
    #
    # @return [String] eg. free_shipping
    def key
      type.demodulize.underscore
    end

    protected

    def label
      Spree.t(:promotion_label, name: promotion.name)
    end
  end
end
