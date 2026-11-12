namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Gives every store the default tax exemption reasons, saves existing
      reason codes in capitals, and links each existing certificate to the
      reason matching its old reason code (Spree 6.0).

      A code no reason holds gets a reason of its own, named after the code.
      Idempotent: reasons the merchant already has are left alone, and a
      certificate already linked is skipped.
    DESC
    task tax_exemption_reasons: :environment do
      # Codes are stored in capitals since tax engines compare them that way;
      # a lookup by code reads capitals too, so a lower-case row would never
      # be found again. Runs before seeding so the seed finds these by code.
      Spree::TaxExemptionReason.find_each do |reason|
        code = Spree::TaxExemptionReason.normalize_value_for(:code, reason.code)
        next if code == reason.code

        if Spree::TaxExemptionReason.where(store_id: reason.store_id).where.not(id: reason.id).exists?(code: code)
          puts "  Left tax exemption reason #{reason.prefixed_id} as #{reason.code}: #{code} is taken in its store"
        else
          reason.update_columns(code: code, updated_at: Time.current)
        end
      end

      Spree::Store.find_each do |store|
        Spree::Seeds::TaxExemptionReasons.call(store: store)
      end

      linked = 0

      Spree::TaxExemptionCertificate.where(tax_exemption_reason_id: nil).where.not(reason_code: [nil, '']).
        includes(company: :store).find_each do |certificate|
        reasons = certificate.company.store.tax_exemption_reasons
        code = Spree::TaxExemptionReason.normalize_value_for(:code, certificate.reason_code)
        name = code.humanize
        name = "#{name} (#{code})" if reasons.where.not(code: code).exists?(name: name)

        reason = reasons.find_or_create_by!(code: code) { |new_reason| new_reason.name = name }
        certificate.update_columns(tax_exemption_reason_id: reason.id, updated_at: Time.current)
        linked += 1
      end

      puts "  Linked #{linked} tax exemption certificate(s) to their reason" if linked.positive?
    end
  end
end
