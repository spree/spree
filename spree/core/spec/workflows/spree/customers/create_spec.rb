require 'spec_helper'

RSpec.describe Spree::Customers::Create do
  let(:store) { @default_store }

  before { Spree.hooks.clear! }
  after { Spree.hooks.clear! }

  describe 'self-registration' do
    subject(:result) do
      described_class.call(
        store: store,
        email: 'new@customer.com',
        password: 'password123',
        password_confirmation: 'password123',
        first_name: 'John',
        last_name: 'Snow'
      )
    end

    it 'creates the customer' do
      expect { result }.to change { Spree.customer_class.count }.by(1)

      expect(result).to be_success
      expect(result.value.email).to eq('new@customer.com')
      expect(result.value.first_name).to eq('John')
    end

    it 'refuses a blank password without creating a record' do
      result = described_class.call(store: store, email: 'new@customer.com')

      expect(result).to be_failure
      expect(result.value.errors[:password]).to be_present
      expect(Spree.customer_class.find_by(email: 'new@customer.com')).to be_nil
    end

    it 'creates a password-less account when the caller waives the requirement' do
      result = described_class.call(store: store, email: 'new@customer.com', password_required: false)

      expect(result).to be_success
      expect(result.value.password_digest).to be_blank
      expect(result.value.valid_password?('anything')).to be(false)
    end

    it 'surfaces validation errors on the unsaved record' do
      result = described_class.call(store: store, email: '', password: 'password123')

      expect(result).to be_failure
      expect(result.value.errors[:email]).to be_present
    end

    it 'links a pre-existing newsletter subscriber to the new account' do
      subscriber = create(:newsletter_subscriber, email: 'new@customer.com', store: store)

      expect(result).to be_success
      expect(subscriber.reload.customer_id).to eq(result.value.id)
    end

    it 'propagates verified newsletter opt-in onto the customer' do
      create(:newsletter_subscriber, :verified, email: 'new@customer.com', store: store)

      expect(result.value.accepts_email_marketing).to be(true)
    end

    it 'lets a validate handler reject the registration' do
      Spree.hooks.register('customers.create.validate') do |workflow|
        workflow.reject!('disposable emails are not accepted') if workflow.customer.email.end_with?('@customer.com')
      end

      expect(result).to be_failure
      expect(result.error.value).to eq('disposable emails are not accepted')
      expect(Spree.customer_class.find_by(email: 'new@customer.com')).to be_nil
    end

    it 'dispatches after_create with the persisted customer' do
      seen = nil
      Spree.hooks.register('customers.create.after_create') { |workflow| seen = workflow.customer }

      expect(result).to be_success
      expect(seen).to eq(result.value)
      expect(seen).to be_persisted
    end
  end

  describe 'checkout account creation (order:)' do
    subject(:result) { described_class.call(store: store, order: order) }

    let(:address) { create(:address, country: store.default_country, firstname: 'John', lastname: 'Snow') }
    let(:order) do
      create(:completed_order_with_totals, bill_address: address, ship_address: address, store: store, customer: nil, email: 'new@customer.com')
    end

    it 'creates the customer from the order' do
      expect { result }.to change { Spree.customer_class.count }.by(1)

      customer = result.value
      expect(customer.email).to eq(order.email)
      expect(customer.first_name).to eq(order.bill_address.firstname)
      expect(customer.last_name).to eq(order.bill_address.lastname)
    end

    it 'creates the account password-less, claimable via password reset' do
      expect(result.value.password_digest).to be_blank
    end

    it 'adopts the order addresses' do
      customer = result.value

      expect(customer.ship_address).to eq(order.ship_address)
      expect(customer.bill_address).to eq(order.bill_address)
      expect(order.bill_address.reload.customer_id).to eq(customer.id)
    end

    it 'links the order to the customer' do
      result

      expect(order.reload.customer).to eq(result.value)
    end

    it 'does not adopt an address that belongs to another customer' do
      other_customer = create(:user)
      address.update_columns(customer_id: other_customer.id)

      customer = result.value

      expect(address.reload.customer_id).to eq(other_customer.id)
      expect(customer.bill_address_id).to be_nil
      expect(customer.ship_address_id).to be_nil
    end

    it 'carries the marketing opt-in from the order' do
      order.update!(accept_marketing: true)

      expect(result.value.accepts_email_marketing).to be(true)
    end

    context 'when a customer with the order email already exists' do
      let!(:existing_customer) { create(:user, email: 'new@customer.com') }

      it 'links the order to the existing account instead of registering' do
        expect { result }.not_to change { Spree.customer_class.count }

        expect(result).to be_success
        expect(result.value).to eq(existing_customer)
        expect(order.reload.customer).to eq(existing_customer)
      end

      it 'does not run registration policy hooks' do
        Spree.hooks.register('customers.create.validate') { |workflow| workflow.reject!('never') }

        expect(result).to be_success
      end

      # The order is already placed — adopting it must never rewrite what
      # the buyer actually checked out with.
      it 'does not backfill order addresses from the adopting account' do
        existing_customer.update!(bill_address: create(:address, country: store.default_country))
        order.update_columns(bill_address_id: nil)

        expect(result).to be_success
        expect(order.reload.bill_address_id).to be_nil
      end
    end
  end
end
