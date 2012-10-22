module Spree
  class Calculator < ActiveRecord::Base
    belongs_to :calculable, :polymorphic => true

    # This method must be overriden in concrete calculator.
    #
    # It should return amount computed based on #calculable and/or optional parameter
    def compute(something=nil)
      raise(NotImplementedError, 'please use concrete calculator')
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
      Rails.application.config.spree.calculators.all
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
