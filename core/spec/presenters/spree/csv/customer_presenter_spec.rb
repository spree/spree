require 'spec_helper'

RSpec.describe Spree::CSV::CustomerPresenter do
  let(:store) { @default_store }
  let(:country) { store.default_country || create(:country, name: 'United States', iso: 'US') }
  let(:state) { country.states.find_by(name: 'California') || create(:state, name: 'California', abbr: 'CA', country: country) }
  let(:address) do
    create(:address,
           company: 'Test Company',
           address1: '123 Main St',
           address2: 'Apt 4B',
           city: 'Los Angeles',
           state: state,
           country: country,
           zipcode: '90210',
           phone: '555-1234')
  end
  let(:customer) do
    create(:user,
           first_name: 'John',
           last_name: 'Doe',
           email: 'john.doe@example.com',
           accepts_email_marketing: true,
           bill_address: address,
           ship_address: address,
           tag_list: ['premium', 'vip'])
  end
  let!(:orders) { create_list(:completed_order_with_totals, 3, user: customer, store: store) }
  let(:presenter) { described_class.new(customer) }

  before do
    orders[0].update_column(:total, 100)
    orders[1].update_column(:total, 200)
    orders[2].update_column(:total, 150)
  end

  describe '#call' do
    subject { presenter.call }

    it 'returns array with correct values' do
      expect(subject[0]).to eq customer.first_name
      expect(subject[1]).to eq customer.last_name
      expect(subject[2]).to eq customer.email
      expect(subject[3]).to eq Spree.t(:say_yes)
      expect(subject[4]).to eq customer.address.company
      expect(subject[5]).to eq customer.address.address1
      expect(subject[6]).to eq customer.address.address2
      expect(subject[7]).to eq customer.address.city
      expect(subject[8]).to eq customer.address.state_text
      expect(subject[9]).to eq customer.address.state_abbr
      expect(subject[10]).to eq customer.address.country.name
      expect(subject[11]).to eq customer.address.country.iso
      expect(subject[12]).to eq customer.address.zipcode
      expect(subject[13]).to eq customer.phone
      expect(subject[14]).to eq customer.amount_spent_in(store.default_currency)
      expect(subject[15]).to eq customer.completed_orders.count
      expect(subject[16]).to eq customer.tag_list
    end

    context 'when customer does not accept email marketing' do
      before { customer.update!(accepts_email_marketing: false) }

      it 'returns say_no for email marketing' do
        expect(subject[3]).to eq Spree.t(:say_no)
      end
    end

    context 'when customer has no address' do
      let(:customer_without_address) do
        create(:user,
               first_name: 'Jane',
               last_name: 'Smith',
               email: 'jane.smith@example.com',
               accepts_email_marketing: false)
      end
      let(:presenter) { described_class.new(customer_without_address) }

      it 'returns nil for address fields' do
        expect(subject[4]).to be_nil # company
        expect(subject[5]).to be_nil # address1
        expect(subject[6]).to be_nil # address2
        expect(subject[7]).to be_nil # city
        expect(subject[8]).to be_nil # state_text
        expect(subject[9]).to be_nil # state_abbr
        expect(subject[10]).to be_nil # country name
        expect(subject[11]).to be_nil # country iso
        expect(subject[12]).to be_nil # zipcode
      end
    end

    context 'when customer has no orders' do
      let(:customer_without_orders) do
        create(:user,
               first_name: 'Bob',
               last_name: 'Johnson',
               email: 'bob.johnson@example.com')
      end
      let(:presenter) { described_class.new(customer_without_orders) }

      it 'returns zero for total orders and amount spent' do
        expect(subject[14]).to eq 0 # amount spent
        expect(subject[15]).to eq 0 # total orders
      end
    end
  end

  describe 'HEADERS constant' do
    it 'contains all expected headers' do
      expected_headers = [
        'First Name',
        'Last Name',
        'Email',
        'Accepts Email Marketing',
        'Company',
        'Address 1',
        'Address 2',
        'City',
        'Province',
        'Province Code',
        'Country',
        'Country Code',
        'Zip',
        'Phone',
        'Total Spent',
        'Total Orders',
        'Tags'
      ]
      expect(described_class::HEADERS).to eq(expected_headers)
    end
  end
end
