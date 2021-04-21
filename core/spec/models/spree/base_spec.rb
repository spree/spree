require 'spec_helper'

module Test
  class Parent < ActiveRecord::Base
    self.table_name = 'test_parents'
  end

  class Child < ActiveRecord::Base
    self.table_name = 'test_children'
    belongs_to :parent, class_name: 'Test::Parent'
  end
end

describe Spree::Base do
  let(:connection) { ActiveRecord::Base.connection }

  before do
    connection.create_table :test_parents, force: true
    connection.create_table :test_children, force: true do |t|
      t.belongs_to :test_parent
    end
  end

  after do
    connection.drop_table 'test_parents', if_exists: true
    connection.drop_table 'test_children', if_exists: true
  end

  it 'does not override Rails 5 default belongs_to_required_by_default' do
    expect(described_class.belongs_to_required_by_default).to eq(false)
    expect(Spree::Product.belongs_to_required_by_default).to be(false)

    expect(ApplicationRecord.belongs_to_required_by_default).to be(true)
    expect(ActiveRecord::Base.belongs_to_required_by_default).to be(true)
    expect(Test::Parent.belongs_to_required_by_default).to be(true)
    expect(Test::Child.belongs_to_required_by_default).to be(true)
  end

  it 'does not disable non-spree, Rails 5 models to validate their associated belongs_to model' do
    model_instance = Test::Child.new

    expect(model_instance.validate).to eq(false)
    expect(model_instance.errors.messages).to include(:parent)
    expect(model_instance.errors.messages[:parent]).to include('must exist')
  end

  describe '.json_api_type' do
    it { expect(Spree::InventoryUnit.json_api_type).to eq('inventory_unit') }
    it { expect(Spree::Address.json_api_type).to eq('address') }
  end

  describe '.json_api_columns' do
    it 'skips sensitive data' do
      expect(Spree::LegacyUser.json_api_columns).not_to include('password')
      expect(Spree::LegacyUser.json_api_columns).to include('email')
    end

    it { expect(Spree::Address.json_api_columns).to contain_exactly('address1', 'address2', 'alternative_phone', 'city', 'company', 'created_at', 'deleted_at', 'firstname', 'label', 'lastname', 'phone', 'state_name', 'updated_at', 'zipcode') }
    it { expect(Spree::Address.json_api_columns).not_to include('country_id') }
  end
end
