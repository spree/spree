require 'spec_helper'

# Deprecated shell — delegates to Spree::Customers::Create. The behavior
# examples stay to prove the delegation preserves the old contract.
describe Spree::Orders::CreateUserAccount do
  subject(:service) { described_class.call(order: order, accepts_email_marketing: accepts_email_marketing) }

  let(:accepts_email_marketing) { false }
  let(:store) { @default_store }
  let(:address) { create(:address, country: store.default_country, firstname: 'John', lastname: 'Snow') }
  let(:order) do
    create(:completed_order_with_totals, bill_address: address, ship_address: address, store: store, customer: nil, email: 'new@customer.com')
  end

  before { allow(Spree::Deprecation).to receive(:warn) }

  it 'warns about the deprecation' do
    service

    expect(Spree::Deprecation).to have_received(:warn).with(/Spree::Customers::Create/)
  end

  context 'when order has no user' do
    let(:new_user) { Spree.customer_class.find_by!(email: order.email) }

    it 'creates a new user' do
      expect { subject }.to change { Spree.customer_class.count }.by(1)

      expect(new_user.email).to eq(order.email)
      expect(new_user.first_name).to eq(order.bill_address.firstname)
      expect(new_user.last_name).to eq(order.bill_address.lastname)
    end

    it 'assigns the ship address to the user' do
      subject
      expect(new_user.ship_address).to eq(order.ship_address)
    end

    it 'assigns the bill address to the user' do
      subject
      expect(new_user.bill_address).to eq(order.bill_address)
    end

    it 'assigns the user to the order' do
      subject
      expect(order.reload.customer).to be_present
      expect(order.customer).to eq(new_user)
    end
  end

  context 'when user with the given email already exists' do
    let!(:user) { create(:user, email: 'new@customer.com') }

    it 'does not create a new user' do
      expect { subject }.to change { Spree.customer_class.count }.by(0)
    end

    it 'assigns the user to the order' do
      subject
      expect(order.reload.customer).to eq(user)
    end

    it 'returns success with the user' do
      expect(subject).to be_success
      expect(subject.value).to eq(user)
    end
  end
end
