class AddAppliedTaxExemptionsToSpreeOrders < ActiveRecord::Migration[8.1]
  # The exemption claims a placed order was priced with, frozen at completion
  # beside its tax registration. Certificates lapse on their own date with
  # nothing written to them, can be revoked, and are destroyed with their
  # company — so resolving them again when a provider files or credits the sale
  # is not the evidence the sale was priced with.
  def change
    change_table :spree_orders, bulk: true do |t|
      if t.respond_to?(:jsonb)
        t.jsonb :applied_tax_exemptions
      else
        t.json :applied_tax_exemptions
      end
    end
  end
end
