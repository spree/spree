module Spree
  class PriceRule < Spree::Base
    acts_as_paranoid
    include Spree::Preferences::Preferable

    belongs_to :price_list, class_name: 'Spree::PriceList'

    validates :type, presence: true
    validates :priority, presence: true, numericality: { only_integer: true }

    scope :by_priority, -> { order(priority: :desc) }

    def applicable?(context)
      raise NotImplementedError, "#{self.class.name} must implement #applicable?"
    end

    def self.human_name
      name.demodulize.titleize
    end

    def self.description
      ''
    end
  end
end
