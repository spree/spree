module Spree
  class Spree::ReturnItem::EligibilityValidator::BaseValidator
    attr_reader :errors

    def initialize(return_item)
      @return_item = return_item
      @errors = {}
    end

    def eligible_for_return?
      raise 'Implement me'
    end

    def requires_manual_intervention?
      raise 'Implement me'
    end

    private

    def add_error(key, error)
      @errors[key] = error
    end
  end
end
