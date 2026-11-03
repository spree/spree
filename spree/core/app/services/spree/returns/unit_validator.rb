module Spree
  module Returns
    # Shared by the return validators that judge the units a customer names:
    # staff may always make an exception, and a refusal names the items.
    # Subclasses implement #call, reading #units_of and calling #refuse.
    class UnitValidator
      private

      def units_of(workflow)
        Array(workflow.items).filter_map { |item| item[:fulfillment_item] }
      end

      def refuse(workflow, code, units)
        workflow.errors.add(
          :base,
          code,
          message: I18n.t("spree.return_errors.#{code}", items: units.map { |unit| unit.variant.name }.uniq.to_sentence)
        )
        workflow.reject!
      end
    end
  end
end
