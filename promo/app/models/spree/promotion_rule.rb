# Base class for all promotion rules
module Spree
  class PromotionRule < ActiveRecord::Base
    belongs_to :promotion, :foreign_key => 'activator_id'

    scope :of_type, lambda {|t| {:conditions => {:type => t}}}

    validate :promotion, :presence => true
    validate :unique_per_activator, :on => :create

    attr_accessible :preferred_operator, :preferred_amount, :product, :product_ids_string, :preferred_match_policy

    def eligible?(order, options = {})
      raise 'eligible? should be implemented in a sub-class of Promotion::PromotionRule'
    end

    private
    def unique_per_activator
      if Spree::PromotionRule.exists?(:activator_id => activator_id, :type => self.class.name)
        errors[:base] << "Promotion already contains this rule type"
      end
    end
 
  end
end
