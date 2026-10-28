module Spree
  # Time zones are stored and exchanged as IANA identifiers (`Europe/Berlin`),
  # the names browsers and every non-Ruby client understand. Rails' display
  # names ("Eastern Time (US & Canada)") are converted to them on the way in.
  module TimeZones
    # The zones clients are offered: the IANA zones Rails gives a display name
    # to, with plain `UTC` standing in for `Etc/UTC`. Any other valid IANA
    # identifier is accepted too; this list only fixes what is suggested, so it
    # stays the same on every machine whatever its time zone database.
    SUGGESTED = (ActiveSupport::TimeZone::MAPPING.values - ['Etc/UTC'] + ['UTC']).uniq.sort.freeze

    # @param identifier [String, nil]
    # @return [Boolean] whether the value is an IANA time zone identifier
    def self.valid?(identifier)
      return false if identifier.blank?

      TZInfo::Timezone.get(identifier.to_s)
      true
    rescue TZInfo::InvalidTimezoneIdentifier
      false
    end

    # @param value [String, nil] an IANA identifier or a Rails time zone name
    # @return [String, nil] the IANA identifier, or the value unchanged when it names no zone
    def self.normalize(value)
      return value if value.blank? || valid?(value)

      ActiveSupport::TimeZone::MAPPING[value.to_s] || value
    end
  end
end
