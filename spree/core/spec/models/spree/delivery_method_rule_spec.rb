require 'spec_helper'

describe Spree::DeliveryMethodRule, type: :model do
  let(:store) { @default_store }
  let(:delivery_method) { create(:delivery_method) }
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

  describe Spree::DeliveryMethodRules::ChannelRule do
    let(:channel) { create(:channel, store: store) }
    let(:other_channel) { create(:channel, store: store) }
    let(:channel_package) do
      order = create(:order_with_line_items, store: store, channel: channel)
      Spree::Stock::Coordinator.new(order).packages.first
    end

    it 'offers the method only on the listed channels' do
      rule = described_class.new(delivery_method: delivery_method)

      # Unconfigured rules fail open, matching the other rule kinds.
      expect(rule.eligible?(channel_package)).to be(true)

      rule.preferred_channel_ids = [channel.id]
      expect(rule.eligible?(channel_package)).to be(true)

      rule.preferred_channel_ids = [other_channel.id]
      expect(rule.eligible?(channel_package)).to be(false)
    end

    it 'hides a channel-restricted method from carts with no channel' do
      rule = described_class.new(delivery_method: delivery_method)
      rule.preferred_channel_ids = [channel.id]

      expect(rule.eligible?(package)).to be(false)
    end

    it 'decodes prefixed ids and rejects channels of another store' do
      rule = described_class.new(delivery_method: delivery_method)
      rule.preferred_channel_ids = [channel.prefixed_id]
      expect(rule.preferred_channel_ids.map(&:to_s)).to eq([channel.id.to_s])

      foreign = create(:channel, store: create(:store))
      expect { rule.preferred_channel_ids = [foreign.id] }.to raise_error(ActiveRecord::RecordNotFound)
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

  describe Spree::DeliveryMethodRules::ExcludedProductsRule do
    it 'blocks packages containing an excluded product and fails open without products' do
      rule = described_class.create!(delivery_method: delivery_method)
      expect(rule.eligible?(package)).to be(true)

      rule.products << package.contents.first.variant.product
      expect(rule.eligible?(package)).to be(false)
    end

    it 'passes packages containing none of the excluded products' do
      rule = described_class.create!(delivery_method: delivery_method, products: [create(:product)])

      expect(rule.eligible?(package)).to be(true)
    end
  end

  # One PATCH saves the method and its conditions together, mirroring
  # Promotion#rules= / PriceList#rules=.
  describe 'Spree::DeliveryMethod#rules=' do
    it 'creates rules alongside a new method in one save' do
      method = Spree::DeliveryMethod.new(name: 'Express', store: store)
      method.rules = [{ type: 'item_total_rule', preferences: { minimum_amount: 50 } }]
      method.save!

      expect(method.delivery_method_rules.reload.sole.preferred_minimum_amount).to eq(50)
    end

    it 'updates, adds and removes rules to match the payload' do
      existing = Spree::DeliveryMethodRules::ItemTotalRule.create!(
        delivery_method: delivery_method, preferences: { minimum_amount: 10 }
      )

      delivery_method.rules = [
        { id: existing.prefixed_id, type: 'item_total_rule', preferences: { minimum_amount: 99 } },
        { type: 'weight_rule', preferences: { maximum_weight: 5 } }
      ]
      delivery_method.save!

      expect(delivery_method.delivery_method_rules.reload.size).to eq(2)
      expect(existing.reload.preferred_minimum_amount).to eq(99)

      delivery_method.rules = []
      delivery_method.save!

      expect(delivery_method.delivery_method_rules.reload).to be_empty
    end

    it 'assigns products on a brand-new association-backed rule' do
      product = create(:product)
      method = Spree::DeliveryMethod.new(name: 'Express', store: store)
      method.rules = [{ type: 'excluded_products_rule', product_ids: [product.id] }]
      method.save!

      expect(method.delivery_method_rules.reload.sole.products).to eq([product])
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
