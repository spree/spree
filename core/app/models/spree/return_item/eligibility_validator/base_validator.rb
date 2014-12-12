module Spree
  class Spree::ReturnItem::EligibilityValidator::BaseValidator
    attr_reader :errors

    def initialize(return_item)
      @return_item = return_item
      @errors = {}
    end

    def eligible_for_return?
      raise NotImplementedError, Spree.t(:implement_eligible_for_return)
    end

    def requires_manual_intervention?
      raise NotImplementedError, Spree.t(:implement_requires_manual_intervention)
    end

    private

    def add_error(key, error)
      @errors[key] = error
    end
  end
end
