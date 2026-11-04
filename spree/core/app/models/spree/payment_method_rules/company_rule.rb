module Spree
  module PaymentMethodRules
    # Offers the method to purchases placed for a company.
    #
    # The company is the one the purchase resolves to, as tax and catalogs
    # read it: a buyer with one membership needs no explicit choice. With
    # companies listed, it or any company above it must be one of them, so
    # "Acme pays on terms" covers Acme's divisions.
    # With none listed, `company_orders_only` decides: on, any company
    # purchase qualifies; off, the rule restricts nothing.
    class CompanyRule < Spree::PaymentMethodRule
      preference :company_ids, :array, of: :id, model: 'Spree::Company', default: [],
                 scope: ->(rule) { rule.store.companies }
      preference :company_orders_only, :boolean, default: true

      def eligible?(purchase)
        return true if preferred_company_ids.empty? && !preferred_company_orders_only

        company = purchase.resolved_company
        return false if company.nil?
        return true if preferred_company_ids.empty?

        listed = preferred_company_ids.map(&:to_s)
        company.self_and_ancestors.any? { |node| listed.include?(node.id.to_s) }
      end
    end
  end
end
