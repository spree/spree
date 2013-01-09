Spree::Adjustment.class_eval do
  class << self
    def promotion
      where(:originator_type => 'Spree::PromotionAction')
    end
  end
end
