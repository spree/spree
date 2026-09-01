module SpreeAvalara
  # Avalara's entity use codes — why a buyer is exempt, in Avalara's own
  # vocabulary. Frozen here rather than seeded into a table: the list is
  # Avalara's, not the merchant's, and the legacy extension's editable table
  # only ever held these same seventeen rows.
  module EntityUseCodes
    ALL = {
      'A' => 'FEDERAL GOV',
      'B' => 'STATE GOV',
      'C' => 'TRIBAL GOVERNMENT',
      'D' => 'FOREIGN DIPLOMAT',
      'E' => 'CHARITABLE/EXEMPT ORG',
      'F' => 'RELIGIOUS ORG',
      'G' => 'RESALE',
      'H' => 'AGRICULTURE',
      'I' => 'INDUSTRIAL PROD/MANUFACTURERS',
      'J' => 'DIRECT PAY',
      'K' => 'DIRECT MAIL',
      'L' => 'OTHER/CUSTOM',
      'N' => 'EDUCATIONAL ORG',
      'P' => 'COMMERCIAL AQUACULTURE',
      'Q' => 'COMMERCIAL FISHERY',
      'R' => 'NON-RESIDENT',
      'TAXABLE' => 'NON-EXEMPT TAXABLE CUSTOMER'
    }.freeze

    # Whatever a merchant recorded on a certificate, said in Avalara's terms. A
    # reason core knows nothing about is still a claim worth sending, so it goes
    # as OTHER/CUSTOM rather than being dropped — the raw reason stays on the
    # row for anyone reading the filing later.
    FALLBACK_CODE = 'L'.freeze

    # Names a merchant is likely to have typed, mapped onto the codes they mean.
    # Derived from the code list itself, so a new code needs no second entry
    # here, plus the aliases the underscore form does not cover.
    REASON_CODE_MAP = ALL.each_with_object({}) { |(code, name), map| map[name] = code }.
                      merge(
                        'FEDERAL_GOV' => 'A',
                        'STATE_GOV' => 'B',
                        'TRIBAL_GOVERNMENT' => 'C',
                        'FOREIGN_DIPLOMAT' => 'D',
                        'CHARITABLE' => 'E',
                        'CHARITABLE_ORG' => 'E',
                        'EXEMPT_ORG' => 'E',
                        'RELIGIOUS_ORG' => 'F',
                        'RESALE' => 'G',
                        'AGRICULTURE' => 'H',
                        'INDUSTRIAL' => 'I',
                        'MANUFACTURER' => 'I',
                        'DIRECT_PAY' => 'J',
                        'DIRECT_MAIL' => 'K',
                        'EDUCATIONAL_ORG' => 'N',
                        'COMMERCIAL_AQUACULTURE' => 'P',
                        'COMMERCIAL_FISHERY' => 'Q',
                        'NON_RESIDENT' => 'R'
                      ).freeze

    # @param reason_code [String, nil] whatever the certificate recorded
    # @return [String, nil] an Avalara entity use code, nil when nothing was claimed
    def self.for(reason_code)
      return if reason_code.blank?

      normalized = reason_code.to_s.strip.upcase
      return normalized if ALL.key?(normalized)

      REASON_CODE_MAP[normalized] || REASON_CODE_MAP[normalized.tr(' ', '_')] || FALLBACK_CODE
    end

    # Whether the code was understood, so a caller can keep the raw reason when
    # it was not.
    #
    # @param reason_code [String, nil]
    # @return [Boolean]
    def self.recognized?(reason_code)
      return false if reason_code.blank?

      normalized = reason_code.to_s.strip.upcase

      ALL.key?(normalized) || REASON_CODE_MAP.key?(normalized) || REASON_CODE_MAP.key?(normalized.tr(' ', '_'))
    end
  end
end
