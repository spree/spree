class PromotionActionLineItem < ActiveRecord::Base

  belongs_to :promotion_action, :class_name => 'Promotion::Actions::CreateLineItems'
  belongs_to :variant

end
