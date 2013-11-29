module Spree
  class Calculator < ActiveRecord::Base
    belongs_to :calculable, polymorphic: true

    # This method calls a compute_<computable> method. must be overriden in concrete calculator.
    #
    # It should return amount computed based on #calculable and the computable parameter
    def compute(computable)
      # Spree::LineItem -> :compute_line_item
      computable_name = computable.class.name.demodulize.underscore
      method = "compute_#{computable_name}".to_sym
      the_caller = caller[0].split(':')[0]
      begin
        self.send(method, computable)
      rescue NoMethodError
        raise NotImplementedError, "Please implement '#{method}(#{computable_name})' in your calculator: #{the_caller}"
      end
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
