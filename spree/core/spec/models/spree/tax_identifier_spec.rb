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

  it 'hands a provider the kind and number only' do
    identifier = create(:tax_identifier, :verified, customer: customer, kind: 'eu_vat', value: 'DE123456789')

    expect(identifier.to_provider_params).to eq(kind: 'eu_vat', value: 'DE123456789')
  end
end
