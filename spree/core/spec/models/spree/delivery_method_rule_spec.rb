require 'spec_helper'

describe Spree::DeliveryMethodRule, type: :model do
  let(:store) { @default_store }
  let(:delivery_method) { create(:shipping_method) }
  let(:package) do
    order = create(:order_with_line_items, store: store, line_items_price: 20)
    Spree::Stock::Coordinator.new(order).packages.first
  end

  describe 'validations' do
    it 'rejects unregistered types' do
      rule = Spree::DeliveryMethodRule.new(type: 'Spree::DeliveryMethodRules::ItemTotalRule', delivery_method: delivery_method)
      expect(rule).to be_valid

      rule = Spree::DeliveryMethodRule.new(delivery_method: delivery_method)
      rule.type = 'Kernel'
      expect(rule).not_to be_valid
      expect(rule.errors[:type]).to be_present
    end

    it 'allows one instance of each rule kind per method' do
      Spree::DeliveryMethodRules::ItemTotalRule.create!(delivery_method: delivery_method)
      duplicate = Spree::DeliveryMethodRules::ItemTotalRule.new(delivery_method: delivery_method)

      expect(duplicate).not_to be_valid
    end
  end

  describe Spree::DeliveryMethodRules::ItemTotalRule do
    it 'bounds by item total inclusively and fails open when unconfigured' do
      rule = described_class.new(delivery_method: delivery_method)
      expect(rule.eligible?(package)).to be(true)

      rule.preferred_minimum_amount = package.item_total
      expect(rule.eligible?(package)).to be(true)

      rule.preferred_minimum_amount = package.item_total + 1
      expect(rule.eligible?(package)).to be(false)

      rule.preferred_minimum_amount = nil
      rule.preferred_maximum_amount = package.item_total - 1
      expect(rule.eligible?(package)).to be(false)
    end
  end

  describe Spree::DeliveryMethodRules::WeightRule do
    it 'bounds by package weight' do
      rule = described_class.new(delivery_method: delivery_method)
      expect(rule.eligible?(package)).to be(true)

      rule.preferred_maximum_weight = package.weight - 1
      expect(rule.eligible?(package)).to be(false)
    end
  end

  describe 'Estimator enforcement' do
    let(:order) { create(:order_with_line_items, store: store, ship_address: create(:address)) }

    it 'drops ineligible methods from rate estimation' do
      fulfillment = order.fulfillments.first || begin
        order.rebuild_fulfillments!
        order.fulfillments.first
      end
      method = fulfillment.refresh_rates.map(&:delivery_method).first
      expect(method).to be_present

      method.delivery_method_rules.create!(
        type: 'Spree::DeliveryMethodRules::ItemTotalRule',
        preferences: { minimum_amount: 1_000_000 }
      )

      expect(fulfillment.reload.refresh_rates.map(&:delivery_method_id)).not_to include(method.id)
    end

    it 'keeps methods whose rules pass' do
      order.rebuild_fulfillments! if order.fulfillments.none?
      fulfillment = order.fulfillments.first
      method = fulfillment.refresh_rates.map(&:delivery_method).first

      method.delivery_method_rules.create!(
        type: 'Spree::DeliveryMethodRules::ItemTotalRule',
        preferences: { minimum_amount: 1 }
      )

      expect(fulfillment.reload.refresh_rates.map(&:delivery_method_id)).to include(method.id)
    end

    it 'ignores inactive rules' do
      order.rebuild_fulfillments! if order.fulfillments.none?
      fulfillment = order.fulfillments.first
      method = fulfillment.refresh_rates.map(&:delivery_method).first

      method.delivery_method_rules.create!(
        type: 'Spree::DeliveryMethodRules::ItemTotalRule',
        active: false,
        preferences: { minimum_amount: 1_000_000 }
      )

      expect(fulfillment.reload.refresh_rates.map(&:delivery_method_id)).to include(method.id)
    end
  end

  describe 'spree:migrate_calculator_bounds_to_delivery_method_rules' do
    before(:all) do
      Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
      load Spree::Core::Engine.root.join('lib', 'tasks', 'delivery_method_rules_migration.rake')
    end

    it 'converts FlatRate bounds into rules and clears the preferences' do
      calculator = delivery_method.calculator
      expect(calculator).to be_a(Spree::Calculator::Shipping::FlatRate)
      calculator.update_columns(preferences: calculator.preferences.merge(minimum_item_total: 25, maximum_weight: 10))

      task = Rake::Task['spree:migrate_calculator_bounds_to_delivery_method_rules']
      task.reenable
      task.invoke

      rules = delivery_method.delivery_method_rules.reload
      item_rule = rules.detect { |rule| rule.is_a?(Spree::DeliveryMethodRules::ItemTotalRule) }
      weight_rule = rules.detect { |rule| rule.is_a?(Spree::DeliveryMethodRules::WeightRule) }

      expect(item_rule.preferred_minimum_amount).to eq(25)
      expect(weight_rule.preferred_maximum_weight).to eq(10)
      expect(calculator.reload.preferences[:minimum_item_total]).to be_nil
    end
  end
end
