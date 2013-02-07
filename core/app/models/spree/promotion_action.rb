# Base class for all types of promotion action.
# PromotionActions perform the necessary tasks when a promotion is activated by an event and determined to be eligible.
module Spree
  class PromotionAction < ActiveRecord::Base
    belongs_to :promotion, foreign_key: 'activator_id', class_name: 'Spree::Promotion'

    scope :of_type, ->(t) { where(type: t) }

    # This method should be overriden in subclass
    # Updates the state of the order or performs some other action depending on the subclass
    # options will contain the payload from the event that activated the promotion. This will include
    # the key :user which allows user based actions to be performed in addition to actions on the order
    def perform(options = {})
      raise 'perform should be implemented in a sub-class of PromotionAction'
    end
  end
end
