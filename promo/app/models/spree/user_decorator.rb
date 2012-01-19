Spree::User.class_eval do
  has_many :pending_promotions
  has_many :promotions, :through => :pending_promotions
end
