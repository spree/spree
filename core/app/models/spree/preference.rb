class Spree::Preference < Spree::Base
  serialize :value

  validates :key, presence: true
end
