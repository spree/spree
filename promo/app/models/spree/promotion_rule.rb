# Base class for all promotion rules
module Spree
  class PromotionRule < ActiveRecord::Base
    belongs_to :promotion, :foreign_key => 'activator_id'

    scope :of_type, lambda {|t| {:conditions => {:type => t}}}

    def eligible?(order, options = {})
      raise 'eligible? should be implemented in a sub-class of Promotion::PromotionRule'
    end
  end
end
