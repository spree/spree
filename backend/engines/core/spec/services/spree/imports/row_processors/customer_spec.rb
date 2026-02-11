require 'spec_helper'

RSpec.describe Spree::Imports::RowProcessors::Customer, type: :service do
  subject { described_class.new(row) }

  let(:store) { Spree::Store.default }
  let(:import) { create(:customer_import, owner: store) }
  let(:row) { create(:import_row, import: import, data: row_data.to_json) }
  let(:csv_row_headers) { Spree::ImportSchemas::Customers.new.headers }

  before do
    import.create_mappings
    create(:country, iso: 'US', name: 'United States') unless Spree::Country.exists?(iso: 'US')
    us = Spree::Country.find_by(iso: 'US')
    create(:state, country: us, abbr: 'NY', name: 'New York') unless us.states.exists?(abbr: 'NY')
    create(:state, country: us, abbr: 'CA', name: 'California') unless us.states.exists?(abbr: 'CA')
  end

  def csv_row_hash(attrs = {})
    csv_row_headers.index_with { |header| attrs[header] }
  end

  context 'when importing a new customer with all fields' do
    let(:row_data) do
      csv_row_hash(
        'email' => 'jane.smith@example.com',
        'first_name' => 'Jane',
        'last_name' => 'Smith',
        'phone' => '555-0101',
        'accepts_email_marketing' => 'yes',
        'tags' => 'VIP, Wholesale',
        'company' => 'Acme Corp',
        'address1' => '123 Main St',
        'address2' => 'Apt 4',
        'city' => 'New York',
        'province_code' => 'NY',
        'country_code' => 'US',
        'zip' => '10001'
      )
    end

    it 'creates a user with correct attributes' do
      user = subject.process!

      expect(user).to be_persisted
      expect(user.email).to eq 'jane.smith@example.com'
      expect(user.first_name).to eq 'Jane'
      expect(user.last_name).to eq 'Smith'
      expect(user.phone).to eq '555-0101'
      expect(user.accepts_email_marketing).to be true
      expect(user.tag_list).to contain_exactly('VIP', 'Wholesale')
    end

    it 'creates an address' do
      user = subject.process!

      address = user.bill_address
      expect(address).to be_persisted
      expect(address.firstname).to eq 'Jane'
      expect(address.lastname).to eq 'Smith'
      expect(address.company).to eq 'Acme Corp'
      expect(address.address1).to eq '123 Main St'
      expect(address.address2).to eq 'Apt 4'
      expect(address.city).to eq 'New York'
      expect(address.zipcode).to eq '10001'
      expect(address.country.iso).to eq 'US'
      expect(address.state.abbr).to eq 'NY'
    end

    it 'sets ship_address when none exists' do
      user = subject.process!

      expect(user.ship_address).to eq user.bill_address
    end

    it 'generates a random password for new users' do
      user = subject.process!

      expect(user.encrypted_password).to be_present
    end
  end

  context 'when importing a customer without address fields' do
    let(:row_data) do
      csv_row_hash(
        'email' => 'maria.garcia@example.com',
        'first_name' => 'Maria',
        'last_name' => 'Garcia',
        'tags' => 'Returning'
      )
    end

    it 'creates a user without an address' do
      user = subject.process!

      expect(user).to be_persisted
      expect(user.email).to eq 'maria.garcia@example.com'
      expect(user.first_name).to eq 'Maria'
      expect(user.last_name).to eq 'Garcia'
      expect(user.bill_address).to be_nil
    end
  end

  context 'when updating an existing customer' do
    let!(:existing_user) do
      create(:user, email: 'jane.smith@example.com', first_name: 'Old', last_name: 'Name')
    end

    let(:row_data) do
      csv_row_hash(
        'email' => 'jane.smith@example.com',
        'first_name' => 'Jane',
        'last_name' => 'Smith',
        'phone' => '555-0101'
      )
    end

    it 'updates the existing user' do
      user = subject.process!

      expect(user.id).to eq existing_user.id
      expect(user.first_name).to eq 'Jane'
      expect(user.last_name).to eq 'Smith'
      expect(user.phone).to eq '555-0101'
    end

    it 'does not overwrite the password' do
      original_password = existing_user.encrypted_password

      subject.process!

      expect(existing_user.reload.encrypted_password).to eq original_password
    end
  end

  context 'when accepts_email_marketing has various values' do
    %w[yes true 1 y].each do |truthy_value|
      it "parses '#{truthy_value}' as true" do
        row_data = csv_row_hash('email' => 'test@example.com', 'accepts_email_marketing' => truthy_value)
        row = create(:import_row, import: import, data: row_data.to_json)
        user = described_class.new(row).process!

        expect(user.accepts_email_marketing).to be true
      end
    end

    %w[no false 0 n].each do |falsy_value|
      it "parses '#{falsy_value}' as false" do
        row_data = csv_row_hash('email' => "test-#{falsy_value}@example.com", 'accepts_email_marketing' => falsy_value)
        row = create(:import_row, import: import, data: row_data.to_json)
        user = described_class.new(row).process!

        expect(user.accepts_email_marketing).to be false
      end
    end
  end

  context 'when email is blank' do
    let(:row_data) { csv_row_hash('email' => '') }

    it 'raises an error' do
      expect { subject.process! }.to raise_error(ArgumentError, 'Email is required')
    end
  end
end
