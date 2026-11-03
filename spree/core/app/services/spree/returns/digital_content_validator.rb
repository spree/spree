module Spree
  module Returns
    # Digital content cannot come back once it has been handed over: there is
    # nothing to send, and the EU right of withdrawal ends when supply begins
    # (Consumer Rights Directive Art. 16(m)). Advisory for staff, who may
    # still refund a download that never worked.
    class DigitalContentValidator < UnitValidator
      # @param workflow [Spree::Returns::Create, Spree::Exchanges::Create]
      def call(workflow)
        return if workflow.created_by.present?

        digital = units_of(workflow).select { |unit| unit.fulfillment&.digital? || unit.variant&.digital? }
        refuse(workflow, :digital_content, digital) if digital.any?
      end
    end
  end
end
