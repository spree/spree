require 'spec_helper'

RSpec.describe SpreeVies::Validator do
  let(:vies_url) { Valvat::Lookup::VIES::ENDPOINT_URI.to_s }
  let(:tax_identifier) { create(:tax_identifier, value: 'IE6388047V') }

  def stub_vies(fixture)
    stub_request(:post, vies_url).to_return(body: file_fixture("vies/#{fixture}.xml").read)
  end

  def validate
    Spree::TaxIdentifiers::Validate.call(tax_identifier: tax_identifier)
    tax_identifier.reload
  end

  it 'takes over EU VAT numbers from the format-only validator' do
    expect(Spree.tax_identifier_validators['eu_vat']).to eq('SpreeVies::Validator')
    expect(tax_identifier).to be_validatable
  end

  context 'when VIES reports the number registered' do
    before { stub_vies(:registered) }

    it 'verifies it and records what VIES returned' do
      validate

      expect(tax_identifier.validation_status).to eq('verified')
      expect(tax_identifier.validation_evidence).to include(
        'registry' => 'vies',
        'qualified' => false,
        'value' => 'IE6388047V',
        'normalized_value' => 'IE6388047V',
        'name' => 'GOOGLE IRELAND LIMITED',
        'address' => '3RD FLOOR, GORDON HOUSE, BARROW STREET, DUBLIN 4'
      )
      expect(tax_identifier.validation_evidence['history'].size).to eq(1)
    end

    it 'keeps the last ten answers, newest first' do
      earlier = Array.new(10) { |index| { 'status' => 'unverified', 'checked_at' => (index + 1).days.ago.iso8601 } }
      tax_identifier.update_columns(validation_evidence: { 'history' => earlier })

      history = validate.validation_evidence['history']

      expect(history.size).to eq(10)
      expect(history.first['status']).to eq('verified')
      expect(history.second).to eq(earlier.first)
    end
  end

  context 'when VIES reports the number not registered' do
    let(:tax_identifier) { create(:tax_identifier, value: 'DE123456788') }

    before { stub_vies(:not_registered) }

    it 'marks it unverified' do
      validate

      expect(tax_identifier.validation_status).to eq('unverified')
      expect(tax_identifier.validation_evidence['message']).to eq('VIES reports this number is not registered')
      expect(tax_identifier.validation_evidence).not_to include('name')
    end
  end

  context 'when the number is not well-formed' do
    before { tax_identifier.update_columns(value: 'IE1234') }

    it 'marks it unverified without asking VIES' do
      validate

      expect(tax_identifier.validation_status).to eq('unverified')
      expect(tax_identifier.validation_evidence['message']).to eq('Not a well-formed EU VAT number')
      expect(a_request(:post, vies_url)).not_to have_been_made
    end
  end

  context 'when VIES cannot answer' do
    before { stub_vies(:ms_unavailable) }

    it 'records the number as unavailable, never as unverified, and asks again later' do
      expect { validate }.to have_enqueued_job(Spree::TaxIdentifiers::ValidateJob).with(tax_identifier.id)

      expect(tax_identifier.validation_status).to eq('unavailable')
      expect(tax_identifier.validation_evidence).to include('registry' => 'vies', 'attempts' => 1)
      expect(tax_identifier.validation_evidence['message']).to include('MS_UNAVAILABLE')
    end

    it 'waits longer after each attempt' do
      tax_identifier.update_columns(validation_evidence: { 'attempts' => 2 })

      Timecop.freeze do
        expect { validate }.to have_enqueued_job(Spree::TaxIdentifiers::ValidateJob).at(20.minutes.from_now)
      end
    end

    it 'stops retrying after the last attempt' do
      tax_identifier.update_columns(validation_evidence: { 'attempts' => described_class::MAX_ATTEMPTS })

      expect { validate }.not_to have_enqueued_job(Spree::TaxIdentifiers::ValidateJob)
      expect(tax_identifier.validation_status).to eq('unavailable')
    end

    it 'keeps the last answer on a scheduled re-check' do
      answered_at = 100.days.ago.change(usec: 0)
      tax_identifier.update_columns(
        validation_status: 'verified',
        validated_at: answered_at,
        validation_evidence: { 'registry' => 'vies', 'name' => 'GOOGLE IRELAND LIMITED', 'history' => [{ 'status' => 'verified' }] }
      )

      validate

      expect(tax_identifier.validation_status).to eq('verified')
      expect(tax_identifier.validated_at).to eq(answered_at)
      expect(tax_identifier.validation_evidence).to include('name' => 'GOOGLE IRELAND LIMITED', 'attempts' => 1)
    end

    it 'drops the attempt count once VIES answers' do
      tax_identifier.update_columns(validation_evidence: { 'attempts' => 2 })
      stub_vies(:registered)

      expect(validate.validation_evidence).not_to include('attempts')
    end
  end

  context 'when the connection fails' do
    before { stub_request(:post, vies_url).to_raise(OpenSSL::SSL::SSLError.new('certificate verify failed')) }

    it 'records the number as unavailable' do
      validate

      expect(tax_identifier.validation_status).to eq('unavailable')
      expect(tax_identifier.validation_evidence['message']).to include('certificate verify failed')
    end
  end

  context 'when VIES is rate limiting' do
    let(:cache) { ActiveSupport::Cache::MemoryStore.new }

    before do
      allow(Rails).to receive(:cache).and_return(cache)
      stub_vies(:global_max_concurrent_req)
    end

    it 'stops asking about any number until the cool-off ends' do
      validate
      other = create(:tax_identifier, value: 'DE123456788')

      expect { Spree::TaxIdentifiers::Validate.call(tax_identifier: other) }
        .to have_enqueued_job(Spree::TaxIdentifiers::ValidateJob).with(other.id)

      expect(a_request(:post, vies_url)).to have_been_made.once
      expect(other.reload.validation_status).to eq('unavailable')
    end

    it 'does not count waiting out the cool-off as an attempt' do
      validate
      other = create(:tax_identifier, value: 'DE123456788')
      other.update_columns(validation_evidence: { 'attempts' => 2 })

      Spree::TaxIdentifiers::Validate.call(tax_identifier: other)

      expect(other.reload.validation_evidence).to include('attempts' => 2)
    end

    it 'spreads the checks it holds back over the cool-off length after it ends' do
      Timecop.freeze do
        validate
        other = create(:tax_identifier, value: 'DE123456788')
        allow_any_instance_of(described_class).to receive(:rand).with(described_class::COOL_OFF.to_i).and_return(123)

        expect { Spree::TaxIdentifiers::Validate.call(tax_identifier: other) }
          .to have_enqueued_job(Spree::TaxIdentifiers::ValidateJob).with(other.id)
          .at(described_class::COOL_OFF.from_now + 123.seconds)
      end
    end
  end

  describe '.due_for_check' do
    def identifier(status, validated_at, updated_at: Time.current, **attributes)
      # update_all, because an order's snapshot is read-only once saved
      create(:tax_identifier, **attributes).tap do |record|
        Spree::TaxIdentifier.where(id: record.id)
                            .update_all(validation_status: status, validated_at: validated_at, updated_at: updated_at)
      end.reload
    end

    it 'selects numbers never asked about, stale answers, exhausted retries and lost checks' do
      never_asked = identifier(nil, nil)
      stale = identifier('verified', 91.days.ago)
      exhausted = identifier('unavailable', 2.days.ago)
      lost_check = identifier('pending', nil, updated_at: 2.hours.ago)
      identifier('verified', 1.day.ago)
      identifier('unavailable', 1.hour.ago)
      identifier('pending', nil)
      identifier(nil, nil, kind: 'au_abn', value: '51824753556')
      identifier('verified', 91.days.ago, owner: create(:order), source: 'customer')

      expect(described_class.due_for_check).to contain_exactly(never_asked, stale, exhausted, lost_check)
    end

    it 'reads the freshness window from SpreeVies.freshness' do
      answered = identifier('unverified', 20.days.ago)
      allow(SpreeVies).to receive(:freshness).and_return(14.days)

      expect(described_class.due_for_check).to contain_exactly(answered)
    end
  end
end
