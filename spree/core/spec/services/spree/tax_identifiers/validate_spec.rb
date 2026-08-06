require 'spec_helper'

describe Spree::TaxIdentifiers::Validate do
  let(:customer) { create(:user) }
  let(:tax_identifier) { create(:tax_identifier, customer: customer, kind: 'eu_vat', value: 'DE123456789') }

  def register(validator_class)
    stub_const('SpecRegistryValidator', validator_class)
    Spree.tax_identifier_validators['eu_vat'] = 'SpecRegistryValidator'
  end

  after { Spree.tax_identifier_validators.delete('eu_vat') }

  context 'when the registry answers' do
    before do
      register(Class.new(Spree::TaxIdentifiers::Validator::Base) do
        def call(tax_identifier:)
          Spree::TaxIdentifiers::ValidationResult.new(
            status: 'verified',
            normalized_value: tax_identifier.value,
            checked_at: Time.current,
            evidence: { 'registry' => 'spec_vies', 'consultation_number' => 'WAPI-1' }
          )
        end
      end)
    end

    it 'records the verdict and the evidence behind it' do
      described_class.call(tax_identifier: tax_identifier)

      tax_identifier.reload
      expect(tax_identifier.validation_status).to eq('verified')
      expect(tax_identifier).to be_verified
      expect(tax_identifier.validated_at).to be_present
      expect(tax_identifier.validation_evidence['consultation_number']).to eq('WAPI-1')
    end

    it 'leaves the number as the buyer entered it' do
      described_class.call(tax_identifier: tax_identifier)

      expect(tax_identifier.reload.value).to eq('DE123456789')
    end

    it 'does not queue itself again' do
      tax_identifier # created (and queued) before the block, so only the write is measured
      clear_enqueued_jobs

      expect { described_class.call(tax_identifier: tax_identifier) }.not_to(
        have_enqueued_job(Spree::TaxIdentifiers::ValidateJob)
      )
    end
  end

  context 'when the registry cannot answer' do
    before do
      register(Class.new(Spree::TaxIdentifiers::Validator::Base) do
        def call(tax_identifier:)
          Spree::TaxIdentifiers::ValidationResult.new(status: 'unavailable', message: 'VIES timed out',
                                                    checked_at: Time.current)
        end
      end)
    end

    it 'records that nobody could answer, leaving the number usable' do
      described_class.call(tax_identifier: tax_identifier)

      tax_identifier.reload
      expect(tax_identifier.validation_status).to eq('unavailable')
      expect(tax_identifier.validation_evidence['message']).to eq('VIES timed out')
    end
  end

  context 'when the validator disappeared between enqueue and run' do
    it 'records unsupported' do
      described_class.call(tax_identifier: tax_identifier)

      expect(tax_identifier.reload.validation_status).to eq('unsupported')
    end
  end

  context 'when the validator raises' do
    before do
      register(Class.new(Spree::TaxIdentifiers::Validator::Base) do
        def call(tax_identifier:)
          raise 'boom'
        end
      end)
      tax_identifier.update_columns(validation_status: 'verified')
    end

    it 'reports the failure and records that nobody could answer' do
      expect(Rails.error).to receive(:report).with(
        instance_of(Spree::TaxIdentifiers::ValidationError), hash_including(:context)
      )

      result = described_class.call(tax_identifier: tax_identifier)

      expect(result).to be_failure
      # Not left on the `pending` the enqueue stamped, and not called wrong.
      expect(tax_identifier.reload.validation_status).to eq('unavailable')
      expect(tax_identifier.validation_evidence['message']).to include('boom')
    end
  end
end
