require 'spec_helper'

RSpec.describe SpreeVies::CheckGuard do
  let(:vies_url) { Valvat::Lookup::VIES::ENDPOINT_URI.to_s }
  let(:tax_identifier) { create(:tax_identifier, value: 'IE6388047V') }
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:lock) { "spree_vies/checking/#{tax_identifier.id}/IE6388047V" }

  before do
    allow(Rails).to receive(:cache).and_return(cache)
    stub_request(:post, vies_url).to_return(body: file_fixture('vies/registered.xml').read)
  end

  it "guards core's ValidateJob, which every check goes through" do
    expect(Spree::TaxIdentifiers::ValidateJob.ancestors).to include(described_class)
  end

  it 'checks the number and releases the guard' do
    Spree::TaxIdentifiers::ValidateJob.perform_now(tax_identifier.id)

    expect(tax_identifier.reload.validation_status).to eq('verified')
    expect(cache.exist?(lock)).to be(false)
  end

  it 'skips a number whose check is already running' do
    cache.write(lock, true)

    Spree::TaxIdentifiers::ValidateJob.perform_now(tax_identifier.id)

    expect(a_request(:post, vies_url)).not_to have_been_made
  end

  it 'still checks a number changed while the old one was being checked' do
    cache.write(lock, true)
    tax_identifier.update_columns(value: 'DE123456788')
    stub_request(:post, vies_url).to_return(body: file_fixture('vies/not_registered.xml').read)

    Spree::TaxIdentifiers::ValidateJob.perform_now(tax_identifier.id)

    expect(tax_identifier.reload.validation_status).to eq('unverified')
  end

  it 'releases the guard when the check fails' do
    allow(Spree::TaxIdentifiers::Validate).to receive(:new).and_raise(ActiveRecord::ConnectionNotEstablished)

    Spree::TaxIdentifiers::ValidateJob.perform_now(tax_identifier.id)

    expect(cache.exist?(lock)).to be(false)
  end
end
