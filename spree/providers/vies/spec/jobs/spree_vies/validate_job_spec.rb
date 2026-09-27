require 'spec_helper'

RSpec.describe SpreeVies::ValidateJob do
  let(:tax_identifier) { create(:tax_identifier, value: 'IE6388047V') }
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:lock) { "spree_vies/checking/#{tax_identifier.id}" }

  before do
    allow(Rails).to receive(:cache).and_return(cache)
    stub_request(:post, Valvat::Lookup::VIES::ENDPOINT_URI.to_s)
      .to_return(body: file_fixture('vies/registered.xml').read)
  end

  it 'checks the number' do
    described_class.perform_now(tax_identifier.id)

    expect(tax_identifier.reload.validation_status).to eq('verified')
    expect(cache.exist?(lock)).to be(false)
  end

  it 'skips a number whose check is already running' do
    cache.write(lock, true)

    described_class.perform_now(tax_identifier.id)

    expect(a_request(:post, Valvat::Lookup::VIES::ENDPOINT_URI.to_s)).not_to have_been_made
  end

  it 'lets the next check run when this one fails' do
    allow(Spree::TaxIdentifier).to receive(:find_by).and_raise(ActiveRecord::ConnectionNotEstablished)

    described_class.perform_now(tax_identifier.id)

    expect(cache.exist?(lock)).to be(false)
  end
end
