module Spree
  class Calculator < ActiveRecord::Base
    belongs_to :calculable, polymorphic: true

    # This method calls a compute_<computable> method. must be overriden in concrete calculator.
    #
    # It should return amount computed based on #calculable and/or optional parameter
    def compute(computable)
      # Spree::LineItem -> :compute_line_item
      method = "compute_#{computable.class.name.demodulize.underscore}".to_sym
      self.send(method, computable)
    end

    # overwrite to provide description for your calculators
    def self.description
      'Base Calculator'
    end

    ###################################################################

    def self.register(*klasses)
    end

    # Returns all calculators applicable for kind of work
    def self.calculators
      Rails.application.config.spree.calculators
    end

    def to_s
      self.class.name.titleize.gsub("Calculator\/", "")
    end

    def description
      self.class.description
    end

    def available?(object)
      true
    end
  end
end
