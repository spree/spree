module Spree
  class PendingPromotion < ActiveRecord::Base
    belongs_to :user
    belongs_to :promotion
  end
end
