class Spree::Preference < Spree::Base
  serialize :value

  validates :key, presence: true, uniqueness: true
end
