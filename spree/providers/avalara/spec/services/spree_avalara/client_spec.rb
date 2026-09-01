require 'spec_helper'

RSpec.describe SpreeAvalara::Client do
  subject(:client) do
    described_class.new(
      account_number: '2000000000',
      license_key: 'test_license_key',
      endpoint: 'https://sandbox-rest.avatax.com',
      company_code: 'DEFAULT'
    )
  end

  let(:ping_url) { 'https://sandbox-rest.avatax.com/api/v2/utilities/ping' }

  def stub_ping(**options)
    stub_request(:get, /#{Regexp.escape(ping_url)}/).to_return(
      { headers: { 'Content-Type' => 'application/json' } }.merge(options)
    )
  end

  describe 'a successful call' do
    it 'returns the parsed body' do
      stub_ping(status: 200, body: { authenticated: true, version: '26.7.0' }.to_json)

      expect(client.ping).to include('authenticated' => true, 'version' => '26.7.0')
    end

    it 'authenticates with the account number and license key' do
      stub_ping(status: 200, body: { authenticated: true }.to_json)

      client.ping

      expect(WebMock).to have_requested(:get, /utilities\/ping/).
        with(basic_auth: ['2000000000', 'test_license_key'])
    end

    # Avalara attributes calls to the certified extension through this header.
    it 'identifies the extension to Avalara' do
      stub_ping(status: 200, body: { authenticated: true }.to_json)

      client.ping

      expect(WebMock).to have_requested(:get, /utilities\/ping/).with { |request|
        request.headers['X-Avalara-Client'].include?(SpreeAvalara::APP_NAME) &&
          request.headers['X-Avalara-Client'].include?(SpreeAvalara::APP_VERSION)
      }
    end
  end

  describe 'timeouts' do
    around do |example|
      original = ENV.to_hash
      example.run
      ENV.replace(original)
    end

    # Reaching for the wrapped SDK client on purpose: the timeouts only matter as
    # what Faraday was actually handed.
    def connection_options_of(built)
      built.send(:avatax_client).connection_options
    end

    it 'holds the cart lock for no longer than the documented defaults' do
      expect(connection_options_of(client)).to eq(request: { open_timeout: 2.0, timeout: 6.0 })
    end

    it 'lets a deployment override them' do
      ENV['SPREE_AVALARA_OPEN_TIMEOUT'] = '0.5'
      ENV['SPREE_AVALARA_READ_TIMEOUT'] = '3.5'

      expect(connection_options_of(client)).to eq(request: { open_timeout: 0.5, timeout: 3.5 })
    end
  end

  describe 'failures' do
    it 'raises with the status and Avalara details on a rejected credential' do
      stub_ping(
        status: 401,
        body: { error: { code: 'AuthenticationIncomplete', message: 'Authentication Incomplete.' } }.to_json
      )

      expect { client.ping }.to raise_error(SpreeAvalara::RequestError) { |error|
        expect(error.status).to eq(401)
        expect(error.message).to eq('Authentication Incomplete.')
        expect(error.details).to include('code' => 'AuthenticationIncomplete')
      }
    end

    it 'raises on a server error even without a parseable body' do
      stub_ping(status: 500, headers: { 'Content-Type' => 'text/html' }, body: '<html>Bad Gateway</html>')

      expect { client.ping }.to raise_error(SpreeAvalara::RequestError) { |error|
        expect(error.status).to eq(500)
        expect(error.message).to include('500')
      }
    end

    # AvaTax also reports refusals inside an otherwise successful response.
    it 'raises when a 200 carries an error object' do
      stub_ping(status: 200, body: { error: { code: 'EntityNotFoundError', message: 'Company not found.' } }.to_json)

      expect { client.ping }.to raise_error(SpreeAvalara::RequestError, 'Company not found.')
    end
  end

  describe 'retries' do
    it 'retries a connection failure twice before giving up' do
      stub_request(:get, /utilities\/ping/).to_raise(Faraday::ConnectionFailed.new('connection refused'))

      expect { client.ping }.to raise_error(SpreeAvalara::RequestError, /connection refused/) { |error|
        # No status: nothing answered, so the failure was the network.
        expect(error.status).to be_nil
      }
      expect(WebMock).to have_requested(:get, /utilities\/ping/).times(3)
    end

    it 'does not repeat a call Avalara already refused' do
      stub_ping(status: 401, body: { error: { message: 'Authentication Incomplete.' } }.to_json)

      expect { client.ping }.to raise_error(SpreeAvalara::RequestError)
      expect(WebMock).to have_requested(:get, /utilities\/ping/).times(1)
    end
  end

  # The SDK subscribes to Faraday notifications every time it is constructed, so
  # a client per call leaks a subscriber per call.
  it 'builds the underlying SDK client once' do
    expect(client.send(:avatax_client)).to be(client.send(:avatax_client))
  end

  describe '#void_transaction' do
    it 'files the void against its own company' do
      stub_request(:post, %r{/api/v2/companies/DEFAULT/transactions/R1001/void}).
        to_return(status: 200, headers: { 'Content-Type' => 'application/json' }, body: { status: 'Cancelled' }.to_json)

      expect(client.void_transaction('R1001')).to include('status' => 'Cancelled')
      expect(WebMock).to have_requested(:post, %r{/companies/DEFAULT/transactions/R1001/void}).
        with(body: { code: 'DocVoided' }.to_json)
    end
  end

  # Which refusals mean "the ledger already says what you wanted it to say".
  # The exact codes are confirmed when the cassettes are recorded.
  describe 'idempotency predicates' do
    def error(code)
      SpreeAvalara::RequestError.new('refused', status: 400, details: { 'code' => code })
    end

    it 'recognises an already-filed document' do
      expect(client.duplicate_document_error?(error('DocumentAlreadyExists'))).to be(true)
      expect(client.duplicate_document_error?(error('EntityNotFoundError'))).to be(false)
    end

    # The code AvaTax actually returns, taken from a recorded cassette.
    it 'recognises a transaction that is already cancelled' do
      expect(client.already_voided_error?(error('TransactionAlreadyCancelled'))).to be(true)
      # Never filed is as good as voided for the caller.
      expect(client.already_voided_error?(error('EntityNotFoundError'))).to be(true)
      expect(client.already_voided_error?(error('AuthenticationIncomplete'))).to be(false)
    end

    # A committed document cannot be recreated, and AvaTax says so through a
    # DocStatus fault rather than by naming a duplicate.
    it 'recognises a committed document as already filed' do
      refusal = SpreeAvalara::RequestError.new(
        'DocStatus is invalid for this operation.', status: 400,
        details: { 'code' => 'GetTaxError', 'details' => [{ 'faultSubCode' => 'DocStatusError' }] }
      )

      expect(client.duplicate_document_error?(refusal)).to be(true)
    end

    # A transport failure carries no details at all.
    it 'claims nothing about a failure Avalara never explained' do
      transport = SpreeAvalara::RequestError.new('connection refused', status: nil)

      expect(client.duplicate_document_error?(transport)).to be(false)
      expect(client.already_voided_error?(transport)).to be(false)
    end
  end
end
