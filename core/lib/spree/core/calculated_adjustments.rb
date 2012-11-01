module Spree
  module Core
    module CalculatedAdjustments
      def self.included(klass)
        klass.class_eval do
          has_one   :calculator, :as => :calculable, :dependent => :destroy
          accepts_nested_attributes_for :calculator
          attr_accessible :calculator_type, :calculator_attributes
          validates :calculator, :presence => true

          def self.calculators
            Rails.application.config.spree.calculators.send(self.to_s.tableize.gsub('/', '_').sub('spree_', ''))
          end

          def calculator_type
            calculator.class.to_s if calculator
          end

          def calculator_type=(calculator_type)
            klass = calculator_type.constantize if calculator_type
            self.calculator = klass.new if klass and not self.calculator.is_a? klass
          end

          # Creates a new adjustment for the target object (which is any class that has_many :adjustments) and
          # sets amount based on the calculator as applied to the calculable argument (Order, LineItems[], Shipment, etc.)
          # By default the adjustment will not be considered mandatory
          def create_adjustment(label, target, calculable, mandatory=false)
            amount = compute_amount(calculable)
            return if amount == 0 && !mandatory
            target.adjustments.create({ :amount => amount,
                                        :source => calculable,
                                        :originator => self,
                                        :label => label,
                                        :mandatory => mandatory}, :without_protection => true)
          end

          # Updates the amount of the adjustment using our Calculator and calling the +compute+ method with the +calculable+
          # referenced passed to the method.
          def update_adjustment(adjustment, calculable)
            adjustment.update_attribute_without_callbacks(:amount, compute_amount(calculable))
          end

          # Calculate the amount to be used when creating an adjustment
          def compute_amount(calculable)
            self.calculator.compute(calculable)
          end
        end
      end
    end
  end
end
