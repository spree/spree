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
  context 'AR overrides', skip: ENV['DB'] == 'mysql' do
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
  end

  describe '.api_type' do
    it { expect(Spree::FulfillmentItem.api_type).to eq('fulfillment_item') }
    it { expect(Spree::Address.api_type).to eq('address') }
  end

  describe '.api_type_for' do
    # Serializers read the STI column rather than `record.class`, so a row
    # loaded through the base class still reports its real type.
    it 'resolves a registered STI type without instantiating it' do
      expect(Spree::Export.api_type_for('Spree::Exports::Orders')).to eq('orders')
      expect(Spree::Import.api_type_for('Spree::Imports::ProductTranslations')).to eq('product_translations')
    end

    it 'falls back to the class itself when the column is blank' do
      expect(Spree::Export.api_type_for(nil)).to eq('export')
      expect(Spree::Export.api_type_for('')).to eq('export')
    end

    # A row written by an extension that is no longer installed must not be
    # constantized — it passes through as-is.
    it 'passes an unregistered value through untouched' do
      expect(Spree::Export.api_type_for('Spree::Exports::Gone')).to eq('Spree::Exports::Gone')
    end

    it 'passes through on a class with no type registry' do
      expect(Spree::Address.api_type_for('Whatever')).to eq('Whatever')
    end
  end

  describe '.json_api_type' do
    # Backwards-compatible alias retained for extensions that still call
    # the old name; must delegate so subclass overrides (e.g.
    # `Spree::Gateway.api_type`) propagate.
    it { expect(Spree::FulfillmentItem.json_api_type).to eq('fulfillment_item') }
    it { expect(Spree::Address.json_api_type).to eq('address') }

    it 'honors subclass overrides of .api_type' do
      klass = Class.new(Spree::Base) do
        def self.api_type
          'overridden'
        end
      end

      expect(klass.json_api_type).to eq('overridden')
    end
  end

  describe '.json_api_columns' do
    it 'skips sensitive data' do
      expect(Spree.customer_class.json_api_columns).not_to include('password')
      expect(Spree.customer_class.json_api_columns).to include('email')
    end

    it { expect(Spree::Address.json_api_columns).to contain_exactly('address1', 'address2', 'alternative_phone', 'city', 'company', 'country_code', 'created_at', 'deleted_at', 'firstname', 'label', 'lastname', 'phone', 'state_code', 'state_name', 'updated_at', 'zipcode', 'metadata', 'quick_checkout', 'latitude', 'longitude') }
    it { expect(Spree::Address.json_api_columns).not_to include('country_id') }
  end

  describe '.json_api_permitted_attributes' do
    it { expect(Spree::Address.json_api_permitted_attributes).to contain_exactly('firstname', 'lastname', 'address1', 'address2', 'city', 'zipcode', 'phone', 'country_code', 'state_code', 'state_name', 'alternative_phone', 'company', 'country_id', 'state_id', 'created_at', 'updated_at', 'customer_id', 'deleted_at', 'label', 'metadata', 'quick_checkout', 'latitude', 'longitude') }
  end

  describe '.additional_permitted_attributes' do
    it 'defaults to an empty list' do
      expect(Spree::Product.additional_permitted_attributes).to eq([])
    end

    it 'is inherited by the STI rule base classes that used to define their own' do
      expect(Spree::PromotionRule.additional_permitted_attributes).to eq([])
      expect(Spree::PromotionAction.additional_permitted_attributes).to eq([])
      expect(Spree::DeliveryMethodRule.additional_permitted_attributes).to eq([])
      expect(Spree::CommissionRule.additional_permitted_attributes).to eq([])
    end

    it 'lets a subclass declare its own without affecting siblings' do
      expect(Spree::Promotion::Rules::Product.additional_permitted_attributes).to eq([product_ids: []])
      expect(Spree::PromotionRule.additional_permitted_attributes).to eq([])
    end

    # The documented extension contract: append from an initializer.
    context 'when an extension appends to it' do
      around do |example|
        original = Spree::Product.additional_permitted_attributes
        example.run
        Spree::Product.additional_permitted_attributes = original
      end

      it 'adds the attribute without touching other models' do
        Spree::Product.additional_permitted_attributes += [:brand_id]

        expect(Spree::Product.additional_permitted_attributes).to eq([:brand_id])
        expect(Spree::Variant.additional_permitted_attributes).to eq([])
        expect(Spree::Base.additional_permitted_attributes).to eq([])
      end

      it 'accumulates across extensions rather than replacing' do
        Spree::Product.additional_permitted_attributes += [:brand_id]
        Spree::Product.additional_permitted_attributes += [{ region_ids: [] }]

        expect(Spree::Product.additional_permitted_attributes).to eq([:brand_id, { region_ids: [] }])
      end
    end
  end

  describe 'preference defaults on load' do
    let(:store) { Spree::Store.default }

    it 'backfills preferences added since the record was last saved' do
      store.update_column(:preferences, store.preferences.except(:timezone))

      loaded = Spree::Store.find(store.id)

      expect(loaded.preferences[:timezone]).to eq(loaded.preference_default(:timezone))
    end

    # `preferences` is a YAML-serialized Hash, so the dirty check compares the
    # serialized string: re-writing the attribute with the same values in a
    # different key order still counts as a change, and `with_lock` refuses a
    # record with unpersisted changes.
    it 'leaves a record clean when the stored preferences only differ in key order' do
      store.update_column(:preferences, store.preferences.to_a.reverse.to_h)

      loaded = Spree::Store.find(store.id)

      expect(loaded).not_to be_changed
      expect { loaded.with_lock { nil } }.not_to raise_error
    end
  end
end
