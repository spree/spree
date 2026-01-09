module Spree
  class PriceRule < Spree.base_class
    belongs_to :price_list, class_name: 'Spree::PriceList', touch: true

    validates :type, :price_list,presence: true

    # Returns true if the price rule is applicable to the context
    # @param context [Spree::Pricing::Context]
    # @return [Boolean]
    def applicable?(context)
      raise NotImplementedError, "#{self.class.name} must implement #applicable?"
    end

    # Returns the human name of the price rule
    # @return [String]
    def self.human_name
      name.demodulize.titleize
    end

    # Returns the description of the price rule
    # @return [String]
    def self.description
      ''
    end
  end
end
