require 'spec_helper'

describe Spree::TaxIdentifiers::Validate do
  let(:customer) { create(:user) }
  # Built before a stub validator is registered in some examples, so it has to
  # survive the format check core ships for eu_vat.
  let(:tax_identifier) { create(:tax_identifier, owner: customer, kind: 'eu_vat') }

  def register(validator_class)
    stub_const('SpecRegistryValidator', validator_class)
    Spree.tax_identifier_validators['eu_vat'] = 'SpecRegistryValidator'
  end

  around do |example|
    with_tax_identifier_validator('eu_vat', Spree.tax_identifier_validators['eu_vat']) { example.run }
  end

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

      entered = tax_identifier.value

      expect(tax_identifier.reload.value).to eq(entered)
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
      # The row has to exist while the validator still does, since creating it
      # is what the format check runs on.
      tax_identifier
      # Deregistered outright, which the surrounding `around` puts back.
      Spree.tax_identifier_validators.delete('eu_vat')

      described_class.call(tax_identifier: tax_identifier)

      expect(tax_identifier.reload.validation_status).to eq('unsupported')
    end
  end

  # Core registers one of these for eu_vat, so this is the ordinary case rather
  # than an edge one: the row must come out marked, not crash the job.
  context 'when the registered validator only checks format' do
    it 'records unsupported without asking anything' do
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
        instance_of(Spree::TaxIdentifiers::ValidationError),
        handled: false,
        context: hash_including(:tax_identifier_id, :kind),
        source: 'spree.core'
      )

      result = described_class.call(tax_identifier: tax_identifier)

      expect(result).to be_failure
      # Not left on the `pending` the enqueue stamped, and not called wrong.
      expect(tax_identifier.reload.validation_status).to eq('unavailable')
      expect(tax_identifier.validation_evidence['message']).to include('boom')
    end
  end

  # The buyer can replace the number while a check is in flight. A verdict about
  # the number they no longer hold must not land on the one they do — it would
  # report a registration as verified when nothing verified it, and that is what
  # decides reverse charge.
  context 'when the number changes while the check runs' do
    before do
      register(Class.new(Spree::TaxIdentifiers::Validator::Base) do
        def call(tax_identifier:)
          # Stands in for the buyer editing the number mid-check.
          tax_identifier.class.where(id: tax_identifier.id).update_all(value: 'DE222222222')
          Spree::TaxIdentifiers::ValidationResult.new(status: 'verified', checked_at: Time.current)
        end
      end)
    end

    it 'discards the verdict rather than writing it onto the new number' do
      described_class.call(tax_identifier: tax_identifier)

      row = tax_identifier.reload
      expect(row.value).to eq('DE222222222')
      expect(row.validation_status).not_to eq('verified')
    end
  end
end
