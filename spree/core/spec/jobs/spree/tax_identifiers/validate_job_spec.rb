require 'spec_helper'

describe Spree::TaxIdentifiers::ValidateJob do
  let(:customer) { create(:user) }
  let(:tax_identifier) { create(:tax_identifier, customer: customer, kind: 'eu_vat') }

  before do
    stub_const('SpecJobValidator', Class.new(Spree::TaxIdentifiers::Validator::Base) do
      def call(tax_identifier:)
        Spree::TaxIdentifiers::ValidationResult.new(status: 'verified', checked_at: Time.current)
      end
    end)
  end

  around do |example|
    with_tax_identifier_validator('eu_vat', 'SpecJobValidator') { example.run }
  end

  it 'records the registry verdict on the row' do
    described_class.perform_now(tax_identifier.id)

    expect(tax_identifier.reload.validation_status).to eq('verified')
  end

  it 'runs on its own queue' do
    expect(described_class.new.queue_name).to eq(Spree.queues.tax_identifiers.to_s)
  end

  it 'does nothing when the row was deleted before the job ran' do
    id = tax_identifier.id
    tax_identifier.destroy!

    expect { described_class.perform_now(id) }.not_to raise_error
  end
end
