require 'spec_helper'

describe Spree::TaxIdentifier, type: :model do
  let(:customer) { create(:user) }
  let(:cart) { create(:cart, customer: customer) }
  let(:order) { create(:order, customer: customer) }

  it 'requires a kind and a value' do
    expect(build(:tax_identifier)).to be_valid
    expect(build(:tax_identifier, kind: nil)).not_to be_valid
    expect(build(:tax_identifier, value: nil)).not_to be_valid
  end

  it 'belongs to exactly one owner' do
    expect(build(:tax_identifier, customer: customer)).to be_valid
    expect(build(:tax_identifier, customer: nil, cart: cart)).to be_valid

    expect(build(:tax_identifier, customer: customer, cart: cart)).not_to be_valid
    expect(build(:tax_identifier, customer: nil)).not_to be_valid
  end

  it 'rejects a validation status the platform never sets' do
    expect(build(:tax_identifier, validation_status: 'verified')).to be_valid
    expect(build(:tax_identifier, validation_status: nil)).to be_valid
    expect(build(:tax_identifier, validation_status: 'probably_fine')).not_to be_valid
  end

  describe 'the order snapshot' do
    it 'is immutable once written' do
      snapshot = create(:tax_identifier, :on_order, order: order)

      expect(snapshot).to be_readonly
      expect { snapshot.update!(value: 'DE999999999') }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it 'is writable while unsaved' do
      expect(build(:tax_identifier, :on_order, order: order)).not_to be_readonly
    end
  end

  it 'is editable while owned by a customer or a cart' do
    expect(create(:tax_identifier, customer: customer)).not_to be_readonly
    expect(create(:tax_identifier, :on_cart, cart: cart)).not_to be_readonly
  end

  describe 'normalization' do
    it 'strips whitespace and upcases, keeping punctuation' do
      identifier = create(:tax_identifier, customer: customer, kind: 'ch_vat', value: ' che-123.456.789 mwst ')

      expect(identifier.value).to eq('CHE-123.456.789MWST')
    end

    it 'rejects a number longer than any real registration' do
      expect(build(:tax_identifier, value: 'D' * 65)).not_to be_valid
    end
  end

  describe 'format validation' do
    let(:validator) do
      Class.new(Spree::TaxIdValidator::Base) do
        def self.valid_format?(value)
          value.start_with?('DE')
        end
      end
    end

    before { stub_const('SpecEuVatValidator', validator) }

    around do |example|
      Spree.tax_id_validators['eu_vat'] = 'SpecEuVatValidator'
      example.run
    ensure
      Spree.tax_id_validators.delete('eu_vat')
    end

    it 'rejects a malformed number as a typo to fix' do
      identifier = build(:tax_identifier, customer: customer, kind: 'eu_vat', value: '123456789')

      expect(identifier).not_to be_valid
      expect(identifier.errors[:value]).to be_present
    end

    it 'accepts a well-formed one' do
      expect(build(:tax_identifier, customer: customer, kind: 'eu_vat', value: 'DE123456789')).to be_valid
    end

    it 'accepts any number for a kind nothing here can check' do
      expect(build(:tax_identifier, customer: customer, kind: 'au_abn', value: 'anything')).to be_valid
    end
  end

  describe 'the registry check' do
    around do |example|
      Spree.tax_id_validators['eu_vat'] = 'Spree::TaxIdValidator::Base'
      example.run
    ensure
      Spree.tax_id_validators.delete('eu_vat')
    end

    it 'is queued when a checkable number is entered, and marked pending' do
      identifier = nil

      expect { identifier = create(:tax_identifier, customer: customer, kind: 'eu_vat') }.to(
        have_enqueued_job(Spree::TaxIdentifiers::ValidateJob)
      )
      expect(identifier.reload.validation_status).to eq('pending')
    end

    it 'is not queued again when something else on the row changes' do
      identifier = create(:tax_identifier, customer: customer, kind: 'eu_vat')

      expect { identifier.update!(source: nil) }.not_to have_enqueued_job(Spree::TaxIdentifiers::ValidateJob)
    end

    it 'is queued again when the number changes' do
      identifier = create(:tax_identifier, customer: customer, kind: 'eu_vat')

      expect { identifier.update!(value: 'DE987654321') }.to have_enqueued_job(Spree::TaxIdentifiers::ValidateJob)
    end

    it 'is skipped for a kind nothing here can check' do
      expect { create(:tax_identifier, customer: customer, kind: 'au_abn') }.not_to(
        have_enqueued_job(Spree::TaxIdentifiers::ValidateJob)
      )
      expect(described_class.last.validation_status).to be_nil
    end

    it 'is skipped for an order snapshot, frozen by definition' do
      expect { create(:tax_identifier, :on_order, order: order, kind: 'eu_vat') }.not_to(
        have_enqueued_job(Spree::TaxIdentifiers::ValidateJob)
      )
    end
  end

  describe '#validatable?' do
    it 'reports whether this installation can check the kind' do
      identifier = create(:tax_identifier, customer: customer, kind: 'eu_vat')
      expect(identifier).not_to be_validatable

      Spree.tax_id_validators['eu_vat'] = 'Spree::TaxIdValidator::Base'
      expect(identifier).to be_validatable
    ensure
      Spree.tax_id_validators.delete('eu_vat')
    end
  end
end
