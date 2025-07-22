require 'spec_helper'

RSpec.describe Spree::Seeds::PaymentMethods do
  subject { described_class.call }

  let(:store_credit_payment_method) { Spree::PaymentMethod::StoreCredit.last }
  let(:store) { @default_store }

  let!(:other_store) { create(:store) }

  it 'creates a Store Credit payment method' do
    expect { subject }.to change(Spree::PaymentMethod::StoreCredit, :count).by(1)

    expect(store_credit_payment_method).to be_present
    expect(store_credit_payment_method).to be_active
    expect(store_credit_payment_method.stores).to include(store, other_store)
    expect(store_credit_payment_method.name).to eq('Store Credit')
    expect(store_credit_payment_method.description).to eq('Store Credit')
  end

  context 'when the Store Credit payment method already exists' do
    before do
      create(
        :store_credit_payment_method,
        stores: [store, other_store],
        name: 'Store Credit',
        description: 'Store Credit',
        active: true
      )
    end

    it "doesn't create a new payment method" do
      expect { subject }.not_to change(Spree::PaymentMethod::StoreCredit, :count)

      expect(store_credit_payment_method).to be_present
      expect(store_credit_payment_method).to be_active
      expect(store_credit_payment_method.stores).to include(store, other_store)
      expect(store_credit_payment_method.name).to eq('Store Credit')
      expect(store_credit_payment_method.description).to eq('Store Credit')
    end
  end
end
