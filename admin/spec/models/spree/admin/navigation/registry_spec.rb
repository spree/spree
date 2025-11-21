require 'spec_helper'

RSpec.describe Spree::Admin::Navigation::Registry do
  let(:registry) { described_class.new(:sidebar) }

  describe '#add' do
    it 'adds a navigation item' do
      item = registry.add(:dashboard, label: 'Dashboard', url: '/admin')

      expect(registry.find(:dashboard)).to eq(item)
    end

    it 'supports block for nested items' do
      registry.add(:products, label: 'Products') do |nav|
        nav.add(:all_products, label: 'All Products')
      end

      parent = registry.find(:products)
      expect(parent.children.size).to eq(1)
      expect(parent.children.first.key).to eq(:all_products)
    end
  end

  describe '#remove' do
    it 'removes a navigation item' do
      registry.add(:dashboard, label: 'Dashboard')
      registry.remove(:dashboard)

      expect(registry.find(:dashboard)).to be_nil
    end

    it 'removes item from parent children' do
      registry.add(:products, label: 'Products') do |nav|
        nav.add(:all_products, label: 'All Products')
      end

      registry.remove(:all_products)

      parent = registry.find(:products)
      expect(parent.children).to be_empty
    end
  end

  describe '#update' do
    it 'updates an existing item' do
      registry.add(:dashboard, label: 'Dashboard', icon: 'home')
      registry.update(:dashboard, label: 'Home', icon: 'house')

      item = registry.find(:dashboard)
      expect(item.label).to eq('Home')
      expect(item.icon).to eq('house')
    end

    it 'returns nil for non-existent item' do
      result = registry.update(:nonexistent, label: 'Test')

      expect(result).to be_nil
    end
  end

  describe '#find' do
    it 'finds an item by key' do
      item = registry.add(:dashboard, label: 'Dashboard')

      expect(registry.find(:dashboard)).to eq(item)
    end

    it 'returns nil for non-existent item' do
      expect(registry.find(:nonexistent)).to be_nil
    end
  end

  describe '#exists?' do
    it 'returns true when item exists' do
      registry.add(:dashboard, label: 'Dashboard')

      expect(registry.exists?(:dashboard)).to be true
    end

    it 'returns false when item does not exist' do
      expect(registry.exists?(:nonexistent)).to be false
    end
  end

  describe '#insert_before' do
    it 'inserts item before target' do
      registry.add(:products, label: 'Products', position: 20)
      registry.insert_before(:products, :orders, label: 'Orders')

      orders = registry.find(:orders)
      products = registry.find(:products)

      expect(orders.position).to be < products.position
    end
  end

  describe '#insert_after' do
    it 'inserts item after target' do
      registry.add(:products, label: 'Products', position: 20)
      registry.insert_after(:products, :customers, label: 'Customers')

      customers = registry.find(:customers)
      products = registry.find(:products)

      expect(customers.position).to be > products.position
    end
  end

  describe '#move' do
    it 'moves item to first position' do
      registry.add(:dashboard, label: 'Dashboard', position: 10)
      registry.add(:products, label: 'Products', position: 20)
      registry.move(:products, position: :first)

      products = registry.find(:products)
      expect(products.position).to eq(-999)
    end

    it 'moves item to last position' do
      registry.add(:dashboard, label: 'Dashboard', position: 10)
      registry.add(:products, label: 'Products', position: 20)
      registry.move(:dashboard, position: :last)

      dashboard = registry.find(:dashboard)
      expect(dashboard.position).to eq(999)
    end

    it 'moves item before another' do
      registry.add(:dashboard, label: 'Dashboard', position: 10)
      registry.add(:products, label: 'Products', position: 20)
      registry.move(:products, before: :dashboard)

      products = registry.find(:products)
      dashboard = registry.find(:dashboard)

      expect(products.position).to be < dashboard.position
    end

    it 'moves item after another' do
      registry.add(:dashboard, label: 'Dashboard', position: 10)
      registry.add(:products, label: 'Products', position: 20)
      registry.move(:dashboard, after: :products)

      dashboard = registry.find(:dashboard)
      products = registry.find(:products)

      expect(dashboard.position).to be > products.position
    end
  end

  describe '#root_items' do
    it 'returns items without parent' do
      registry.add(:dashboard, label: 'Dashboard')
      registry.add(:products, label: 'Products') do |nav|
        nav.add(:all_products, label: 'All Products')
      end

      root_items = registry.root_items

      expect(root_items.size).to eq(2)
      expect(root_items.map(&:key)).to contain_exactly(:dashboard, :products)
    end

    it 'returns items sorted by position' do
      registry.add(:products, label: 'Products', position: 20)
      registry.add(:dashboard, label: 'Dashboard', position: 10)

      root_items = registry.root_items

      expect(root_items.first.key).to eq(:dashboard)
      expect(root_items.last.key).to eq(:products)
    end
  end

  describe '#visible_items' do
    it 'returns all items when no conditions' do
      registry.add(:dashboard, label: 'Dashboard')
      registry.add(:products, label: 'Products')

      visible = registry.visible_items(nil)

      expect(visible.size).to eq(2)
    end

    it 'filters items based on condition with view context' do
      context = Object.new
      def context.admin?
        true
      end

      registry.add(:dashboard, label: 'Dashboard')
      registry.add(:admin_panel, label: 'Admin', if: -> { admin? })
      registry.add(:restricted, label: 'Restricted', if: -> { false })

      visible = registry.visible_items(context)

      expect(visible.map(&:key)).to contain_exactly(:dashboard, :admin_panel)
    end
  end

  describe '#section' do
    it 'creates a section header' do
      section = registry.section(:main, label: 'Main Section')

      expect(section.section?).to be true
      expect(section.section_label).to eq('Main Section')
    end

    it 'supports block for section items' do
      registry.section(:main, label: 'Main Section') do |nav|
        nav.add(:dashboard, label: 'Dashboard')
        nav.add(:products, label: 'Products')
      end

      section = registry.find(:main)
      expect(section.children.size).to eq(2)
    end
  end

  describe '#clear' do
    it 'removes all items' do
      registry.add(:dashboard, label: 'Dashboard')
      registry.add(:products, label: 'Products')
      registry.clear

      expect(registry.root_items).to be_empty
    end
  end
end
