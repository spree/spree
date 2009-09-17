module HasCalculator
  module ClassMethods
    def has_calculator(options = {})
      has_one   :calculator, :as => :calculable, :dependent => :destroy
      accepts_nested_attributes_for :calculator
      validates_presence_of(:calculator) if options[:require]

      class_inheritable_accessor :calculators
      self.calculators = []
      # @available_calculators = []
      def register_calculator(calculator)
        self.calculators << calculator
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
  end

  def self.included(receiver)
  	receiver.extend  ClassMethods
  end
end
