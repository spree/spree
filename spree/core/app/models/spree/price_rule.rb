module Spree
  class PriceRule < Spree.base_class
    has_prefix_id :prule

    belongs_to :price_list, class_name: 'Spree::PriceList', touch: true

    delegate :store, to: :price_list

    validates :type, :price_list, presence: true
    validates :type, uniqueness: { scope: [:price_list_id, *spree_base_uniqueness_scope] }

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

    registers_subclasses_via { Array(Spree.pricing&.rules) }
  end
end
