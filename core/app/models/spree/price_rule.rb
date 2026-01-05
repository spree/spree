module Spree
  class PriceRule < Spree::Base
    acts_as_paranoid
    include Spree::Preferences::Preferable

    belongs_to :price_list, class_name: 'Spree::PriceList'

    validates :type, presence: true

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
