class AddTaxExemptionReasonToSpreeTaxExemptionCertificates < ActiveRecord::Migration[8.1]
  def change
    # Nullable, and reason_code kept: certificates recorded before reasons
    # existed are linked by `spree:upgrade:tax_exemption_reasons`, which reads
    # their reason_code.
    add_reference :spree_tax_exemption_certificates, :tax_exemption_reason
    change_column_null :spree_tax_exemption_certificates, :reason_code, true
  end
end
