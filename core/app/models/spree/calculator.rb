module Spree
  class Calculator < Spree::Base
    # Conditional check for backwards compatibilty since acts as paranoid was added late https://github.com/spree/spree/issues/5858
    if ActiveRecord::Base.connected? && connection.data_source_exists?(:spree_calculators) && connection.column_exists?(:spree_calculators, :deleted_at)
      acts_as_paranoid
    end

    belongs_to :calculable, polymorphic: true, optional: true

    # This method calls a compute_<computable> method. must be overriden in concrete calculator.
    #
    # It should return amount computed based on #calculable and the computable parameter
    def compute(computable)
      # Spree::LineItem -> :compute_line_item
      computable_name = computable.class.name.demodulize.underscore
      method = "compute_#{computable_name}".to_sym
      calculator_class = self.class
      if respond_to?(method)
        send(method, computable)
      else
        raise NotImplementedError, "Please implement '#{method}(#{computable_name})' in your calculator: #{calculator_class.name}"
      end
    end

    # overwrite to provide description for your calculators
    def self.description
      'Base Calculator'
    end

    def self.calculators_for(adjustment_type)
      calculators = Rails.application.config.spree.calculators[adjustment_type].sort_by(&:name)
      if adjustment_type == :shipping_methods
        calculators.select { |c| c.to_s.constantize < Spree::ShippingCalculator }
      else
        calculators
      end
    end

    def to_s
      self.class.name.titleize.gsub("Calculator\/", '')
    end

    def description
      self.class.description
    end

    def available?(_object)
      true
    end
  end
end
