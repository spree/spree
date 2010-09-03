module Spree::CalculatedAdjustments
  module ClassMethods
    def calculated_adjustments(options = {})
      has_one   :calculator, :as => :calculable, :dependent => :destroy
      accepts_nested_attributes_for :calculator
      validates :calculator, :presence => true if options[:require]

      class_inheritable_accessor :calculators
      self.calculators = Set.new
      # @available_calculators = []
      def register_calculator(calculator)
        self.calculators.add(calculator)
      end
      # def calculators
      #   @available_calculators
      # end

      if options[:default]
        default_calculator_class = options[:default]
        #if default_calculator_class.available?(self.new)
          before_create :default_calculator
          define_method(:default_calculator) do
            self.calculator ||= default_calculator_class.new
          end
        # else
        #   raise(ArgumentError, "calculator #{default_calculator_class} can't be used with #{self}")
        # end
      else
        define_method(:default_calculator) do
          nil
        end
      end

      include InstanceMethods
    end
  end

  module InstanceMethods
    def calculator_type
      calculator.class.to_s if calculator
    end

    def calculator_type=(calculator_type)
      clazz = calculator_type.constantize if calculator_type
      self.calculator = clazz.new if clazz and not self.calculator.is_a? clazz
    end

    # Creates a new adjustment for the target object (which is any class that has_many :adjustments) and
    # sets amount based on the calculator as applied to the calculable argument (Order, LineItems[], Shipment, etc.)
    # By default the adjustment will not be considered mandatory
    def create_adjustment(label, target, calculable, mandatory=false)
      amount = self.calculator.compute(calculable)
      target.adjustments.create(:amount => amount, :source => calculable, :originator => self, :label => label, :mandatory => mandatory)
    end

    # Updates the amount of the adjustment using our Calculator and calling the +compute+ method with the +calculable+
    # referenced passed to the method.
    def update_adjustment(adjustment, calculable)
      adjustment.update_attribute_without_callbacks(:amount, self.calculator.compute(calculable))
    end
  end

  def self.included(receiver)
    receiver.extend Spree::CalculatedAdjustments::ClassMethods
  end
end
