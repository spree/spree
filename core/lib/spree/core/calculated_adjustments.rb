module Spree
  module Core
    module CalculatedAdjustments
      def self.included(klass)
        klass.class_eval do
          has_one   :calculator, :class_name => "Spree::Calculator", :as => :calculable, :dependent => :destroy
          accepts_nested_attributes_for :calculator
          attr_accessible :calculator_type, :calculator_attributes
          validates :calculator, :presence => true

          def self.calculators
            spree_calculators.send model_name_without_spree_namespace
          end

          def calculator_type
            calculator.class.to_s if calculator
          end

          def calculator_type=(calculator_type)
            klass = calculator_type.constantize if calculator_type
            self.calculator = klass.new if klass && !self.calculator.is_a?(klass)
          end

          # Creates a new adjustment for the target object (which is any class that has_many :adjustments) and
          # sets amount based on the calculator as applied to the calculable argument (Order, LineItems[], Shipment, etc.)
          # By default the adjustment will not be considered mandatory
          def create_adjustment(label, target, calculable, mandatory=false, state="closed")
            # Adjustment calculations done on Spree::Shipment objects MUST
            # be done on their to_package'd variants instead
            # It's only the package that contains the correct information.
            # See https://github.com/spree/spree_active_shipping/pull/96 et. al
            old_calculable = calculable
            calculable = calculable.to_package if calculable.is_a?(Spree::Shipment)
            amount = compute_amount(calculable)
            return if amount == 0 && !mandatory
            target.adjustments.create({ :amount => amount,
                                        :source => old_calculable,
                                        :originator => self,
                                        :label => label,
                                        :mandatory => mandatory,
                                        :state => state }, :without_protection => true)
          end

          # Updates the amount of the adjustment using our Calculator and calling the +compute+ method with the +calculable+
          # referenced passed to the method.
          def update_adjustment(adjustment, calculable)
            # Adjustment calculations done on Spree::Shipment objects MUST
            # be done on their to_package'd variants instead
            # It's only the package that contains the correct information.
            # See https://github.com/spree/spree_active_shipping/pull/96 et. al
            calculable = calculable.to_package if calculable.is_a?(Spree::Shipment)
            adjustment.update_attribute_without_callbacks(:amount, compute_amount(calculable))
          end

          # Calculate the amount to be used when creating an adjustment
          # NOTE: May be overriden by classes where this module is included into.
          # Such as Spree::Promotion::Action::CreateAdjustment.
          def compute_amount(calculable)
            self.calculator.compute(calculable)
          end

          private
          def self.model_name_without_spree_namespace
            self.to_s.tableize.gsub('/', '_').sub('spree_', '')
          end

          def self.spree_calculators
            Rails.application.config.spree.calculators
          end
        end
      end
    end
  end
end
