module SpreeVies
  # Asks VIES, the EU's VAT Information Exchange System, whether an EU VAT
  # number is registered — the registry half that core's format-only
  # {Spree::TaxIdentifiers::Validator::EuVat} leaves to an extension.
  #
  # VIES relays each question to the member state's own registry, and those go
  # down routinely. So "could not ask" and "not registered" are kept strictly
  # apart: only a registry saying no makes a number +unverified+, and an outage
  # never becomes a rejection. A check that could not be answered is queued
  # again with a growing delay.
  #
  # Every answer is recorded as evidence alongside the verdict, with the checks
  # before it, because VIES only ever answers "registered now" — and the audit
  # question for a zero-rated sale is whether the number was registered then.
  class Validator < Spree::TaxIdentifiers::Validator::EuVat
    REGISTRY = 'vies'.freeze
    HISTORY_LIMIT = 10
    TIMEOUT = 10.seconds
    MAX_ATTEMPTS = 8
    FIRST_RETRY = 5.minutes
    LAST_RETRY = 6.hours
    # How long every check waits after VIES reports too many concurrent
    # requests. The limit is VIES-wide, so asking about another number sooner
    # only extends it.
    COOL_OFF = 10.minutes
    COOL_OFF_KEY = 'spree_vies/cool_off_until'.freeze

    # Everything that means nobody answered, as opposed to a registry saying no.
    # VIES faults arrive as Valvat::LookupError; the rest are the network's.
    UNANSWERED_ERRORS = [
      Valvat::LookupError, ::Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError
    ].freeze

    def self.checks_registry?
      true
    end

    # EU VAT numbers that should be asked about again: never asked, answered
    # longer ago than {SpreeVies.freshness}, or left unanswered after every
    # retry of a day. Order snapshots are never re-checked.
    #
    # @return [ActiveRecord::Relation<Spree::TaxIdentifier>]
    def self.due_for_check
      identifiers = Spree::TaxIdentifier.for_kind('eu_vat').where.not(owner_type: 'Spree::Order')

      answered = identifiers.where(validation_status: %w[verified unverified], validated_at: ...SpreeVies.freshness.ago)
      exhausted = identifiers.where(validation_status: 'unavailable', validated_at: ...1.day.ago)

      identifiers.where(validation_status: nil).or(answered).or(exhausted)
    end

    # @param tax_identifier [Spree::TaxIdentifier]
    # @return [Spree::TaxIdentifiers::ValidationResult]
    def call(tax_identifier:)
      @tax_identifier = tax_identifier
      unless self.class.valid_format?(tax_identifier.value)
        return answered(nil, message: 'Not a well-formed EU VAT number')
      end
      if cool_off_remaining.positive?
        return unanswered('VIES asked for fewer concurrent requests; waiting before asking again')
      end

      details = Valvat::Lookup.validate(
        tax_identifier.value,
        detail: true,
        raise_error: true,
        http: { open_timeout: TIMEOUT.to_i, read_timeout: TIMEOUT.to_i }
      )
      answered(details.presence)
    rescue Valvat::RateLimitError => error
      Rails.cache.write(COOL_OFF_KEY, COOL_OFF.from_now, expires_in: COOL_OFF)
      unanswered(error.message)
    rescue *UNANSWERED_ERRORS => error
      unanswered(error.message)
    end

    private

    # @param details [Hash, nil] what VIES returned for a registered number, nil
    #   when it is not registered
    def answered(details, message: nil)
      checked_at = Time.current
      status = details ? 'verified' : 'unverified'
      check = {
        'status' => status,
        'value' => @tax_identifier.value,
        'checked_at' => checked_at.iso8601,
        # Qualified checks — which need the store's own VAT number — are what
        # return a consultation number. Until a store can record one, every
        # check is a plain one, and the evidence says so.
        'qualified' => false,
        'consultation_number' => details&.dig(:request_identifier),
        'name' => details&.dig(:name),
        'address' => details&.dig(:address)
      }.compact

      Spree::TaxIdentifiers::ValidationResult.new(
        status: status,
        checked_at: checked_at,
        message: message || (details ? nil : 'VIES reports this number is not registered'),
        normalized_value: details && "#{details[:country_code]}#{details[:vat_number]}",
        evidence: check.merge('registry' => REGISTRY, 'history' => [check, *history].first(HISTORY_LIMIT))
      )
    end

    # A scheduled re-check that cannot reach VIES leaves the last answer about
    # this number standing rather than replacing it with "unavailable": the
    # number was registered when last asked, and an outage is no evidence
    # otherwise. Its date stays the old one, so it is asked about again.
    def unanswered(message)
      attempts = previous_evidence['attempts'].to_i + 1
      retry_later(attempts)
      attempt = { 'registry' => REGISTRY, 'attempts' => attempts, 'unanswered_at' => Time.current.iso8601 }

      if @tax_identifier.validation_status.in?(%w[verified unverified])
        Spree::TaxIdentifiers::ValidationResult.new(
          status: @tax_identifier.validation_status,
          checked_at: @tax_identifier.validated_at,
          message: message,
          normalized_value: previous_evidence['normalized_value'],
          evidence: previous_evidence.merge(attempt)
        )
      else
        Spree::TaxIdentifiers::ValidationResult.new(
          status: 'unavailable', checked_at: Time.current, message: message,
          evidence: attempt.merge('history' => history)
        )
      end
    end

    def retry_later(attempts)
      return if attempts > MAX_ATTEMPTS

      wait = [FIRST_RETRY * (2**(attempts - 1)), LAST_RETRY].min
      Spree::TaxIdentifiers::ValidateJob.set(wait: [wait, cool_off_remaining].max).perform_later(@tax_identifier.id)
    end

    def cool_off_remaining
      until_time = Rails.cache.read(COOL_OFF_KEY)
      until_time ? [until_time - Time.current, 0].max : 0
    end

    # Answers only: the attempts in between would push out the answers an
    # audit needs.
    def history
      Array(previous_evidence['history'])
    end

    def previous_evidence
      @previous_evidence ||= (@tax_identifier.validation_evidence || {}).to_h.except('message')
    end
  end
end
