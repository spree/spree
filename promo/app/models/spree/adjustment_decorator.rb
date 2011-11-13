module Spree
  class Adjustment.class_eval do
    scope :promotion, lambda { where('label LIKE ?', "#{I18n.t(:promotion)}%") }
  end
end
