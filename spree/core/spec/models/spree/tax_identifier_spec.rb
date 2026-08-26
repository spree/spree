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

  it 'requires an owner' do
    expect(build(:tax_identifier, owner: customer)).to be_valid
    expect(build(:tax_identifier, owner: cart)).to be_valid
    expect(build(:tax_identifier, owner: nil)).not_to be_valid
  end

  it 'rejects a validation status the platform never sets' do
    expect(build(:tax_identifier, validation_status: 'verified')).to be_valid
    expect(build(:tax_identifier, validation_status: nil)).to be_valid
    expect(build(:tax_identifier, validation_status: 'probably_fine')).not_to be_valid
  end

  describe 'the order snapshot' do
    it 'is immutable once written' do
      snapshot = create(:tax_identifier, :on_order, owner: order)

      expect(snapshot).to be_readonly
      # A valid number, so it is the readonly guard that refuses the write and
      # not the format check standing in front of it.
      expect { snapshot.update!(value: Spree::TestingSupport::VatNumberPool.at(9)) }.to(
        raise_error(ActiveRecord::ReadOnlyRecord)
      )
    end

    it 'is writable while unsaved' do
      expect(build(:tax_identifier, :on_order, owner: order)).not_to be_readonly
    end
  end

  it 'is editable while owned by a customer or a cart' do
    expect(create(:tax_identifier, owner: customer)).not_to be_readonly
    expect(create(:tax_identifier, :on_cart, owner: cart)).not_to be_readonly
  end

  describe 'normalization' do
    it 'strips whitespace and upcases, keeping punctuation' do
      identifier = create(:tax_identifier, owner: customer, kind: 'ch_vat', value: ' che-123.456.789 mwst ')

      expect(identifier.value).to eq('CHE-123.456.789MWST')
    end

    it 'rejects a number longer than any real registration' do
      expect(build(:tax_identifier, value: 'D' * 65)).not_to be_valid
    end
  end

  describe 'format validation' do
    let(:validator) do
      Class.new(Spree::TaxIdentifiers::Validator::Base) do
        def self.valid_format?(value)
          value.start_with?('DE')
        end
      end
    end

    before { stub_const('SpecEuVatValidator', validator) }

    around do |example|
      with_tax_identifier_validator('eu_vat', 'SpecEuVatValidator') { example.run }
    end

    it 'rejects a malformed number as a typo to fix' do
      identifier = build(:tax_identifier, owner: customer, kind: 'eu_vat', value: '123456789')

      expect(identifier).not_to be_valid
      expect(identifier.errors[:value]).to be_present
    end

    it 'accepts a well-formed one' do
      expect(build(:tax_identifier, owner: customer, kind: 'eu_vat', value: 'DE123456789')).to be_valid
    end

    it 'accepts any number for a kind nothing here can check' do
      expect(build(:tax_identifier, owner: customer, kind: 'au_abn', value: 'anything')).to be_valid
    end
  end

  # No stubbed validator here on purpose: this is what a stock install does.
  describe 'the EU VAT format check core ships' do
    it 'rejects a mistyped VAT number' do
      identifier = build(:tax_identifier, owner: customer, kind: 'eu_vat', value: 'DE123')

      expect(identifier).not_to be_valid
      expect(identifier.errors[:value]).to be_present
    end

    it 'accepts a well-formed one' do
      expect(
        build(:tax_identifier, owner: customer, kind: 'eu_vat',
                               value: Spree::TestingSupport::VatNumberPool.at(0))
      ).to be_valid
    end

    it 'reports one problem, not two, for a blank number' do
      identifier = build(:tax_identifier, owner: customer, kind: 'eu_vat', value: '')

      expect(identifier).not_to be_valid
      expect(identifier.errors[:value]).to eq(identifier.errors[:value].uniq)
      expect(identifier.errors[:value].size).to eq(1)
    end

    # A registration accepted before a rule tightened — or one whose country
    # has since left the VAT area — must not fail the order it was placed on.
    it 'does not re-check a number frozen onto an order' do
      snapshot = build(:tax_identifier, owner: create(:order), kind: 'eu_vat',
                                        value: 'GB123456789', source: 'customer')

      expect(snapshot).to be_valid
    end

    # An initializer left behind after its gem was dropped names a class that
    # no longer loads. That used to be inert, and it is read on every save and
    # every admin serialization.
    it 'treats an unloadable registered validator as absent' do
      with_tax_identifier_validator('eu_vat', 'NoSuchValidatorConstant') do
        identifier = build(:tax_identifier, owner: customer, kind: 'eu_vat', value: 'anything')

        expect { identifier.valid? }.not_to raise_error
        expect(identifier).to be_valid
        expect { identifier.validatable? }.not_to raise_error
        expect(identifier).not_to be_validatable
      end
    end

    # Being well-formed is not evidence that the business is registered, and
    # only a registry can supply that — so a stock install leaves the verdict
    # blank rather than queueing a check nobody here can answer.
    it 'records no verdict and queues nothing', events: true do
      identifier = nil

      expect { identifier = create(:tax_identifier, owner: customer, kind: 'eu_vat') }.not_to(
        have_enqueued_job(Spree::TaxIdentifiers::ValidateJob)
      )

      expect(identifier.validation_status).to be_nil
      expect(identifier).not_to be_validatable
    end
  end

  # The check now runs from Spree::TaxIdentifierValidationSubscriber, so these
  # need the event bus the suite disables by default.
  describe 'the registry check', events: true do
    around do |example|
      with_tax_identifier_validator('eu_vat', 'Spree::TaxIdentifiers::Validator::Base') { example.run }
    end

    it 'is queued when a checkable number is entered, and marked pending' do
      identifier = nil

      expect { identifier = create(:tax_identifier, owner: customer, kind: 'eu_vat') }.to(
        have_enqueued_job(Spree::TaxIdentifiers::ValidateJob)
      )
      expect(identifier.reload.validation_status).to eq('pending')
    end

    it 'is not queued again when something else on the row changes' do
      identifier = create(:tax_identifier, owner: customer, kind: 'eu_vat')

      expect { identifier.update!(source: nil) }.not_to have_enqueued_job(Spree::TaxIdentifiers::ValidateJob)
    end

    it 'is queued again when the number changes' do
      identifier = create(:tax_identifier, owner: customer, kind: 'eu_vat')

      expect { identifier.update!(value: Spree::TestingSupport::VatNumberPool.at(5)) }.to(
        have_enqueued_job(Spree::TaxIdentifiers::ValidateJob)
      )
    end

    # The stamp is part of the write, not the subscriber's doing: the response to
    # the request that changed the number must not report a stale verdict, and it
    # must hold even where the event bus is switched off.
    it 'marks the row pending on the object that was saved, without reloading' do
      identifier = Spree::Events.disable { create(:tax_identifier, owner: customer, kind: 'eu_vat') }

      expect(identifier.validation_status).to eq('pending')
      expect(identifier.validated_at).to be_nil
    end

    # Purchase::Taxation#best_of prefers a verified row, so a verdict left behind
    # on a kind nothing can check would be actively chosen to decide tax.
    it 'clears the verdict when the kind becomes one nothing can check' do
      identifier = create(:tax_identifier, owner: customer, kind: 'eu_vat')
      identifier.update_columns(validation_status: 'verified', validated_at: Time.current)

      identifier.update!(kind: 'au_abn', value: '51824753556')

      expect(identifier).not_to be_validatable
      expect(identifier.validation_status).to be_nil
      expect(identifier.validated_at).to be_nil
      expect(identifier).not_to be_verified
    end

    it 'clears an earlier verdict when the number changes' do
      identifier = create(:tax_identifier, owner: customer, kind: 'eu_vat')
      identifier.update_columns(validation_status: 'verified', validated_at: Time.current)

      identifier.update!(value: Spree::TestingSupport::VatNumberPool.at(7))

      expect(identifier.validation_status).to eq('pending')
      expect(identifier.validated_at).to be_nil
    end

    it 'is skipped for a kind nothing here can check' do
      expect { create(:tax_identifier, owner: customer, kind: 'au_abn') }.not_to(
        have_enqueued_job(Spree::TaxIdentifiers::ValidateJob)
      )
      expect(described_class.last.validation_status).to be_nil
    end

    it 'is skipped for an order snapshot, frozen by definition' do
      expect { create(:tax_identifier, :on_order, owner: order, kind: 'eu_vat') }.not_to(
        have_enqueued_job(Spree::TaxIdentifiers::ValidateJob)
      )
    end
  end

  describe '#validatable?' do
    it 'reports whether this installation can check the kind' do
      identifier = create(:tax_identifier, owner: customer, kind: 'eu_vat')
      expect(identifier).not_to be_validatable

      with_tax_identifier_validator('eu_vat', 'Spree::TaxIdentifiers::Validator::Base') do
        expect(identifier).to be_validatable
      end
    end
  end

  describe 'a company owner' do
    let(:company) { create(:company, store: @default_store) }

    it 'is a valid sole owner' do
      expect(build(:tax_identifier, owner: company)).to be_valid
    end

    it 'holds one registration per kind' do
      create(:tax_identifier, owner: company, kind: 'eu_vat')

      expect(build(:tax_identifier, owner: company, kind: 'eu_vat')).not_to be_valid
    end

    it 'reports the company as its owner' do
      identifier = create(:tax_identifier, owner: company)

      expect(identifier.owner).to eq(company)
    end
  end
  # A seller's registration faces the other way from the rest: it is what the
  # marketplace's own commission invoice is made out to, and what makes EU
  # reverse charge on that fee possible.
  describe 'a seller owner' do
    let(:seller) { create(:seller) }

    it 'is a valid owner' do
      identifier = described_class.new(owner: seller, kind: 'eu_vat',
                                       value: Spree::TestingSupport::VatNumberPool.at(0))

      expect(identifier).to be_valid
      expect(identifier.owner).to eq(seller)
    end

    it 'holds one registration per kind' do
      described_class.create!(owner: seller, kind: 'eu_vat',
                              value: Spree::TestingSupport::VatNumberPool.at(0))
      duplicate = described_class.new(owner: seller, kind: 'eu_vat',
                                      value: Spree::TestingSupport::VatNumberPool.at(1))

      expect(duplicate).not_to be_valid
    end
  end

end
