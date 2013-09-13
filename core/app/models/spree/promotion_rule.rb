# Base class for all promotion rules
module Spree
  class PromotionRule < ActiveRecord::Base
    belongs_to :promotion, foreign_key: 'activator_id', class_name: 'Spree::Promotion'

    scope :of_type, ->(t) { where(type: t) }

    validate :promotion, presence: true
    validate :unique_per_activator, on: :create

    def self.for(promotable)
      all.select { |rule| rule.applicable?(promotable) }
    end

    def applicable?(promotable)
      raise 'applicable? should be implemented in a sub-class of Spree::PromotionRule'
    end

    def eligible?(promotable, options = {})
      raise 'eligible? should be implemented in a sub-class of Spree::PromotionRule'
    end

    private
    def unique_per_activator
      if Spree::PromotionRule.exists?(activator_id: activator_id, type: self.class.name)
        errors[:base] << "Promotion already contains this rule type"
      end
    end
 
  end
end
