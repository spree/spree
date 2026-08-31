require 'spec_helper'

RSpec.describe Spree::Addresses::Create do
  subject { described_class }

  let(:customer) { create(:customer) }
  let(:address_params) do
    {
      firstname: 'John',
      lastname: 'Doe',
      company: 'Company',
      address1: '1 Main Street',
      address2: 'Northwest',
      city: 'New York',
      zipcode: '10001',
      phone: '555-555-0199',
      alternative_phone: '555-555-0199',
      state_code: 'NY',
      country_code: 'US'
    }
  end

  describe '#call' do
    it 'creates the address and makes it the owner\'s default of both kinds' do
      result = subject.call(address_params: address_params.dup, owner: customer)

      expect(result).to be_success
      expect(customer.reload.addresses.count).to eq(1)
      expect(customer.bill_address_id).to eq(result.value.id)
      expect(customer.ship_address_id).to eq(result.value.id)
    end

    context 'when the owner already has the same address' do
      let!(:existing) { subject.call(address_params: address_params.dup, owner: customer).value }

      it 'returns the entry the book already holds' do
        result = subject.call(address_params: address_params.dup, owner: customer)

        expect(result).to be_success
        expect(result.value).to eq(existing)
      end

      it 'does not add a second copy' do
        expect {
          subject.call(address_params: address_params.dup, owner: customer)
        }.not_to change { customer.reload.addresses.count }
      end

      it 'reuses the entry even when the country is written in lower case' do
        result = subject.call(
          address_params: address_params.merge(country_code: 'us', state_code: 'ny'),
          owner: customer
        )

        expect(result.value).to eq(existing)
      end

      it 'still moves the requested default onto it' do
        other = subject.call(address_params: address_params.merge(address1: '2 Main Street'), owner: customer).value
        customer.reload.update!(bill_address_id: other.id)

        subject.call(address_params: address_params.dup, owner: customer, default_billing: true)

        expect(customer.reload.bill_address_id).to eq(existing.id)
      end

      # The entry keeps the name it was filed under. Returning the existing,
      # differently named entry would drop the label and make a second one
      # impossible.
      it 'files a second entry when the request names it differently' do
        first = subject.call(address_params: address_params.merge(label: 'Dock A'), owner: customer)
        second = subject.call(address_params: address_params.merge(label: 'Dock B'), owner: customer)

        expect(second).to be_success
        expect(second.value.id).not_to eq(first.value.id)
        expect(second.value.label).to eq('Dock B')
      end

      # The label is taken precisely because the entry is already there, so the
      # answer is that entry — never "name has already been taken".
      it 'returns the existing entry when the request repeats its label' do
        first = subject.call(address_params: address_params.merge(label: 'Dock A'), owner: customer)
        repeat = subject.call(address_params: address_params.merge(label: 'Dock A'), owner: customer)

        expect(repeat).to be_success
        expect(repeat.value.id).to eq(first.value.id)
      end

      it 'creates a new address when a field differs' do
        expect {
          subject.call(address_params: address_params.merge(address1: '2 Main Street'), owner: customer)
        }.to change { customer.reload.addresses.count }.by(1)
      end
    end

    # Finding no entry and then filing one is a read the write depends on, and
    # no unique index stands behind it.
    it 'serializes writes to one book so simultaneous requests cannot each file an entry' do
      expect(customer).to receive(:with_lock).once.and_call_original

      expect(subject.call(address_params: address_params.dup, owner: customer)).to be_success
    end

    it 'writes an ownerless address without a book to serialize on' do
      result = subject.call(address_params: address_params.dup)

      expect(result).to be_success
      expect(result.value).to be_persisted
      expect(result.value.owner).to be_nil
    end

    context 'when another customer has the same address' do
      let(:other_customer) { create(:customer) }

      before { subject.call(address_params: address_params.dup, owner: other_customer) }

      it 'creates its own entry rather than reusing theirs' do
        result = subject.call(address_params: address_params.dup, owner: customer)

        expect(result.value.owner).to eq(customer)
        expect(customer.reload.addresses.count).to eq(1)
      end
    end

    context 'with invalid params' do
      it 'fails without creating anything' do
        expect {
          expect(subject.call(address_params: address_params.merge(address1: nil), owner: customer)).to be_failure
        }.not_to change { Spree::Address.count }
      end
    end
  end
end
