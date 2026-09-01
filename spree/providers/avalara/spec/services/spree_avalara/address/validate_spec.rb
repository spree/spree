require 'spec_helper'

RSpec.describe SpreeAvalara::Address::Validate do
  subject(:service) { described_class.new }

  let!(:integration) { create(:avalara_integration, :active, store: @default_store) }
  let(:client) { instance_double(SpreeAvalara::Client) }
  let(:address) { build(:address, city: 'Seattle', state_code: 'WA', country_code: 'US', zipcode: '98109') }

  before do
    allow(SpreeAvalara::Integration).to receive(:active_for!).with(@default_store).and_return(integration)
    allow(integration).to receive(:client).and_return(client)
  end

  it 'accepts an address Avalara resolves' do
    allow(client).to receive(:resolve_address).and_return('validatedAddresses' => [{ 'city' => 'Seattle' }])

    result = service.call(address: address, store: @default_store)

    expect(result).to be_success
    expect(result.error).to be_nil
  end

  it 'sends the address Avalara needs to resolve it' do
    allow(client).to receive(:resolve_address).and_return({})

    service.call(address: address, store: @default_store)

    expect(client).to have_received(:resolve_address).with(hash_including(postalCode: '98109', region: 'WA'))
  end

  it 'refuses an address Avalara reports an error for' do
    allow(client).to receive(:resolve_address).and_return(
      'messages' => [{ 'severity' => 'Error', 'summary' => 'The address is not deliverable.' }]
    )

    result = service.call(address: address, store: @default_store)

    expect(result).not_to be_success
    expect(result.error.summary).to eq('The address is not deliverable.')
    expect(result.error).not_to be_transport
  end

  # A corrected street name is a note, not a refusal.
  it 'accepts an address Avalara only comments on' do
    allow(client).to receive(:resolve_address).and_return(
      'messages' => [{ 'severity' => 'Information', 'summary' => 'Street name standardised.' }]
    )

    expect(service.call(address: address, store: @default_store)).to be_success
  end

  it 'marks an unreachable Avalara as a transport failure rather than a bad address' do
    allow(client).to receive(:resolve_address).
      and_raise(SpreeAvalara::RequestError.new('connection refused', status: nil))

    result = service.call(address: address, store: @default_store)

    expect(result).not_to be_success
    expect(result.error).to be_transport
  end

  it 'treats a refusal Avalara answered as a judgement about the address' do
    allow(client).to receive(:resolve_address).
      and_raise(SpreeAvalara::RequestError.new('Bad request.', status: 400))

    expect(service.call(address: address, store: @default_store).error).not_to be_transport
  end

  # Avalara validates US and Canadian addresses only, so there is no opinion to
  # be had about anywhere else.
  it 'has no opinion outside the countries Avalara covers' do
    german = build(:address, country_code: 'DE')

    expect(service.call(address: german, store: @default_store)).to be_success
    expect(client).not_to have_received(:resolve_address) if client.respond_to?(:resolve_address)
  end

  it 'has no opinion without an address' do
    expect(service.call(address: nil, store: @default_store)).to be_success
  end
end
