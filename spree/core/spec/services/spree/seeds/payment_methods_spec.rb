require 'spec_helper'

RSpec.describe Spree::Seeds::PaymentMethods do
  subject { described_class.call }

  let(:store) { @default_store }

  let!(:other_store) { create(:store) }

  it 'creates a Store Credit payment method for each store' do
    expect { subject }.to change(Spree::PaymentMethod::StoreCredit, :count).by(2)

    [store, other_store].each do |s|
      payment_method = s.payment_methods.store_credit.first
      expect(payment_method).to be_present
      expect(payment_method).to be_active
      expect(payment_method.store).to eq(s)
      expect(payment_method.name).to eq('Store Credit')
      expect(payment_method.description).to eq('Store Credit')
    end
  end

  context 'when a store already has a Store Credit payment method' do
    before do
      [store, other_store].each do |s|
        create(
          :store_credit_payment_method,
          store: s,
          name: 'Store Credit',
          description: 'Store Credit',
          active: true
        )
      end
    end

    it "doesn't create a new payment method" do
      expect { subject }.not_to change(Spree::PaymentMethod::StoreCredit, :count)
    end
  end
end
