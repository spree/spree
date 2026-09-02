module SpreeAvalara
  # Avalara's entity use codes — why a buyer is exempt, in Avalara's own
  # vocabulary. Frozen here rather than seeded into a table: the list is
  # Avalara's, not the merchant's, and the legacy extension's editable table
  # only ever held these same seventeen rows.
  #
  # Two directions, because two callers need opposite things. The dashboard
  # offers the merchant this list (code to label, registered in the engine) and
  # sends back a code. A reason recorded some other way — a hand-written API
  # call, an importer — may arrive as a name instead, and {.for} resolves it.
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

    # A reason Avalara cannot classify is still a claim worth sending, so it
    # goes as OTHER/CUSTOM rather than being dropped — the raw reason stays on
    # the row for anyone reading the filing later.
    FALLBACK_CODE = 'L'.freeze

    # Name to code, derived so a new code needs no second entry. Nothing is
    # hand-aliased onto it: a name this does not hold is a name nobody can
    # show Avalara meant, and guessing files the wrong exemption. Unknown
    # reasons take the fallback, which files a claim Avalara will look at.
    BY_NAME = ALL.each_with_object({}) { |(code, label), index| index[label] = code }.freeze

    # @param reason_code [String, nil] whatever the certificate recorded
    # @return [String, nil] an Avalara entity use code, nil when nothing was claimed
    def self.for(reason_code)
      return if reason_code.blank?

      value = normalize(reason_code)
      return value if ALL.key?(value)

      BY_NAME[value] || FALLBACK_CODE
    end

    # Whether the code was understood, so a caller can keep the raw reason when
    # it was not.
    #
    # @param reason_code [String, nil]
    # @return [Boolean]
    def self.recognized?(reason_code)
      return false if reason_code.blank?

      value = normalize(reason_code)

      ALL.key?(value) || BY_NAME.key?(value)
    end

    # One form for both indexes, so 'federal_gov', 'Federal Gov' and
    # 'FEDERAL  GOV' are read as the same claim.
    def self.normalize(value)
      value.to_s.strip.upcase.tr('_', ' ').squeeze(' ')
    end
    private_class_method :normalize
  end
end
