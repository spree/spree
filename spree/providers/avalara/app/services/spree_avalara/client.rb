module SpreeAvalara
  # The only place this gem talks to AvaTax. Wraps Avalara's SDK client so
  # callers deal in Spree vocabulary: a parsed body on success, a
  # {SpreeAvalara::RequestError} on anything else.
  #
  # The legacy extension achieved the same by monkey-patching the SDK's request
  # method. Nothing is patched here — error translation lives in this wrapper,
  # which is also what makes the SDK upgradable.
  class Client
    # Nothing was answered, so these become a statusless RequestError and the
    # caller reports the engine as unavailable.
    #
    # Deliberately translated but never repeated here. Repeating means sleeping
    # inside the request, which holds a thread — and the completion lock — while
    # a customer waits, and a timeout has already spent the whole read budget
    # before it even begins. Retrying belongs to the caller: the response says
    # 503, and the SDK retries that with backoff of its own.
    TRANSPORT_ERRORS = [Faraday::ConnectionFailed, Faraday::TimeoutError].freeze

    # Fields of Avalara's answers that identify the merchant's account rather
    # than the sale; the ping names the account number as the user name.
    UNLOGGED_FIELDS = %w[authenticatedAccountId authenticatedUserId authenticatedUserName accountId
                         createdUserId modifiedUserId crmid].freeze

    # How many tax codes one search returns; enough to pick from as you type.
    TAX_CODE_SEARCH_LIMIT = 50

    attr_reader :account_number, :license_key, :endpoint, :company_code, :logging

    # @param account_number [String] AvaTax account number, sent as the username
    # @param license_key [String] AvaTax license key, sent as the password
    # @param endpoint [String] AvaTax host, sandbox or production
    # @param company_code [String, nil] the company documents are filed against
    # @param logging [Boolean] write every call to the Rails log
    def initialize(account_number:, license_key:, endpoint:, company_code: nil, logging: false)
      @account_number = account_number
      @license_key = license_key
      @endpoint = endpoint
      @company_code = company_code
      @logging = logging
    end

    # Whether these credentials authenticate, plus the account they belong to.
    #
    # @return [Hash]
    def ping
      request(:ping) { avatax_client.ping }
    end

    # @param model [Hash] a CreateTransactionModel
    # @return [Hash] the created transaction
    def create_transaction(model)
      request(:create_transaction, model) { avatax_client.create_transaction(model) }
    end

    # Files a transaction, adjusting it in place when the document code has been
    # filed before — which is what makes committing an order replayable.
    #
    # @param model [Hash] a CreateOrAdjustTransactionModel
    # @return [Hash] the filed transaction
    def create_or_adjust_transaction(model)
      request(:create_or_adjust_transaction, model) { avatax_client.create_or_adjust_transaction(model) }
    end

    # @param transaction_code [String] the document code to void
    # @param code [String] AvaTax's void reason
    # @return [Hash] the voided transaction
    def void_transaction(transaction_code, code: 'DocVoided')
      model = { code: code }
      request(:void_transaction, model.merge(transaction_code: transaction_code)) do
        avatax_client.void_transaction(company_code, transaction_code, model)
      end
    end

    # Whether the account holds a company with this code. A ping proves the
    # credentials and nothing else, so a mistyped code would otherwise surface
    # only at the first checkout.
    #
    # @param code [String]
    # @return [Boolean]
    def company_exists?(code)
      options = { '$filter' => "companyCode eq #{odata_literal(code)}", '$top' => 1 }
      body = request(:query_companies, options) { avatax_client.query_companies(options) }

      Array(body['value']).any?
    end

    # Avalara's active tax codes whose code or description contains the query.
    #
    # @param query [String]
    # @return [Array<Hash>] Avalara's tax code records
    def list_tax_codes(query)
      term = odata_literal(query)
      options = {
        '$filter' => "(taxCode contains #{term} OR description contains #{term}) AND isActive eq true",
        '$top' => TAX_CODE_SEARCH_LIMIT,
        '$orderBy' => 'taxCode ASC'
      }

      Array(request(:list_tax_codes, options) { avatax_client.list_tax_codes(options) }['value'])
    end

    # @param params [Hash] address parts (line1, city, region, postalCode, country)
    # @return [Hash] the resolved address with Avalara's messages
    def resolve_address(params)
      request(:resolve_address, params) { avatax_client.resolve_address(params) }
    end

    # Whether a refusal means the document is already filed. Commit is
    # replayable — a crash between the order commit and the cart stamp leaves
    # completion to re-run — so filing the same code twice has to count as
    # success rather than raise.
    #
    # @param error [SpreeAvalara::RequestError]
    # @return [Boolean]
    def duplicate_document_error?(error)
      # The two names remain unconfirmed — no recording has produced them.
      return true if error_code(error).in?(%w[DocumentAlreadyExists DuplicateDocumentException])

      # What a replay actually answers: a committed document with this code cannot
      # be recreated or adjusted, so AvaTax refuses with GetTaxError / DocStatusError
      # ("Expected Saved|Posted") rather than naming a duplicate. The document
      # is filed, which is the state the caller wanted.
      fault_sub_codes(error).include?('DocStatusError')
    end

    # Whether a refusal means there is nothing left to void: already voided, or
    # never filed at all. Both leave the ledger where the caller wanted it.
    #
    # @param error [SpreeAvalara::RequestError]
    # @return [Boolean]
    def already_voided_error?(error)
      # TransactionAlreadyCancelled is what AvaTax actually answers, confirmed
      # against a recorded cassette: "The transaction ... is already in a
      # 'Cancelled' status. There is nothing to be done." EntityNotFoundError
      # covers a document that was never filed, which leaves the ledger where
      # the caller wanted it just the same.
      error_code(error).in?(%w[TransactionAlreadyCancelled EntityNotFoundError])
    end

    private

    def error_code(error)
      details = error.try(:details)

      details.is_a?(Hash) ? details['code'].to_s : ''
    end

    def fault_sub_codes(error)
      details = error.try(:details)
      return [] unless details.is_a?(Hash)

      Array(details['details']).filter_map { |entry| entry['faultSubCode'] if entry.is_a?(Hash) }
    end

    # Every option the SDK reads is passed explicitly: its initializer merges the
    # process-wide `AvaTax.options` underneath, so an unset option silently
    # inherits whatever a host app configured globally.
    #
    # Memoized because the SDK subscribes to Faraday notifications on every
    # instantiation — a client built per call leaks a subscriber per call for the
    # life of the process.
    def avatax_client
      @avatax_client ||= AvaTax::Client.new(
        username: account_number,
        password: license_key,
        endpoint: endpoint,
        app_name: SpreeAvalara::APP_NAME,
        app_version: SpreeAvalara::APP_VERSION,
        machine_name: nil,
        # Replaces the SDK's own 20-minute request timeout: an estimate runs
        # inside the cart's transaction, so waiting that long holds a lock.
        connection_options: ::AvaTax::Configuration::DEFAULT_CONNECTION_OPTIONS.merge(
          request: { open_timeout: SpreeAvalara.open_timeout, timeout: SpreeAvalara.read_timeout }
        ),
        # The status is needed to tell a duplicate document from a rejection, and
        # the SDK hands it over only with the whole response.
        faraday_response: true,
        logger: false,
        custom_logger: nil,
        proxy: nil,
        response_big_decimal_conversion: false
      )
    end

    def request(operation, payload = nil)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      begin
        response = yield
      rescue *TRANSPORT_ERRORS => error
        log_call(operation, payload, started, outcome: error.class.name)
        # No status: nothing was answered, so the failure is the network rather
        # than a decision by Avalara.
        raise RequestError.new(error.message, status: nil, details: nil)
      end

      log_call(operation, payload, started, outcome: response.status, response: response.body)
      interpret(response)
    end

    # One line per call, for a merchant tracing what was sent and what came back.
    # Bodies only, since the credentials travel in the Authorization header, and
    # with the account's own identifiers taken out of the answers.
    def log_call(operation, payload, started, outcome:, response: nil)
      return unless logging

      duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      Rails.logger.info(
        "[AVATAX] #{operation} #{outcome} #{duration}ms request=#{payload.to_json} response=#{without_account(response).to_json}"
      )
    end

    def without_account(body)
      @account_filter ||= ActiveSupport::ParameterFilter.new(UNLOGGED_FIELDS.map { |field| /\A#{field}\z/ })
      body.is_a?(Hash) ? @account_filter.filter(body) : body
    end

    # OData quotes a literal with single quotes and escapes one inside it by
    # doubling it.
    def odata_literal(value)
      "'#{value.to_s.gsub("'", "''")}'"
    end

    # AvaTax reports refusals two ways — an HTTP status and an `error` object in
    # an otherwise successful body — and both mean the call did not do what was
    # asked.
    def interpret(response)
      status = response.status
      body = response.body
      details = body.is_a?(Hash) ? body['error'] : nil

      return body if status.to_i.between?(200, 299) && details.blank?

      raise RequestError.new(failure_message(status, details), status: status, details: details)
    end

    def failure_message(status, details)
      details_message = details.is_a?(Hash) ? details['message'].presence : nil

      details_message || "AvaTax request failed with status #{status}"
    end
  end
end
