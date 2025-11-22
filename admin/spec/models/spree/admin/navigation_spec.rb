require 'spec_helper'

RSpec.describe Spree::Admin::Navigation do
  let(:navigation) { described_class.new(:sidebar) }

  describe '#add' do
    it 'adds a navigation item' do
      item = navigation.add(:dashboard, label: 'Dashboard', url: '/admin')

      expect(navigation.find(:dashboard)).to eq(item)
    end

    it 'supports block for nested items' do
      navigation.add(:products, label: 'Products') do |nav|
        nav.add(:all_products, label: 'All Products')
      end

      parent = navigation.find(:products)
      expect(parent.children.size).to eq(1)
      expect(parent.children.first.key).to eq(:all_products)
    end
  end

  describe '#remove' do
    it 'removes a navigation item' do
      navigation.add(:dashboard, label: 'Dashboard')
      navigation.remove(:dashboard)

      expect(navigation.find(:dashboard)).to be_nil
    end

    it 'removes item from parent children' do
      navigation.add(:products, label: 'Products') do |nav|
        nav.add(:all_products, label: 'All Products')
      end

      navigation.remove(:all_products)

      parent = navigation.find(:products)
      expect(parent.children).to be_empty
    end
  end

  describe '#update' do
    it 'updates an existing item' do
      navigation.add(:dashboard, label: 'Dashboard', icon: 'home')
      navigation.update(:dashboard, label: 'Home', icon: 'house')

      item = navigation.find(:dashboard)
      expect(item.label).to eq('Home')
      expect(item.icon).to eq('house')
    end

    it 'returns nil for non-existent item' do
      result = navigation.update(:nonexistent, label: 'Test')

      expect(result).to be_nil
    end
  end

  describe '#find' do
    it 'finds an item by key' do
      item = navigation.add(:dashboard, label: 'Dashboard')

      expect(navigation.find(:dashboard)).to eq(item)
    end

    it 'returns nil for non-existent item' do
      expect(navigation.find(:nonexistent)).to be_nil
    end
  end

  describe '#exists?' do
    it 'returns true when item exists' do
      navigation.add(:dashboard, label: 'Dashboard')

      expect(navigation.exists?(:dashboard)).to be true
    end

    it 'returns false when item does not exist' do
      expect(navigation.exists?(:nonexistent)).to be false
    end
  end

  describe '#insert_before' do
    it 'inserts item before target' do
      navigation.add(:products, label: 'Products', position: 20)
      navigation.insert_before(:products, :orders, label: 'Orders')

      orders = navigation.find(:orders)
      products = navigation.find(:products)

      expect(orders.position).to be < products.position
    end
  end

  describe '#insert_after' do
    it 'inserts item after target' do
      navigation.add(:products, label: 'Products', position: 20)
      navigation.insert_after(:products, :customers, label: 'Customers')

      customers = navigation.find(:customers)
      products = navigation.find(:products)

      expect(customers.position).to be > products.position
    end
  end

  describe '#move' do
    it 'moves item to first position' do
      navigation.add(:dashboard, label: 'Dashboard', position: 10)
      navigation.add(:products, label: 'Products', position: 20)
      navigation.move(:products, position: :first)

      products = navigation.find(:products)
      expect(products.position).to eq(-999)
    end

    it 'moves item to last position' do
      navigation.add(:dashboard, label: 'Dashboard', position: 10)
      navigation.add(:products, label: 'Products', position: 20)
      navigation.move(:dashboard, position: :last)

      dashboard = navigation.find(:dashboard)
      expect(dashboard.position).to eq(999)
    end

    it 'moves item before another' do
      navigation.add(:dashboard, label: 'Dashboard', position: 10)
      navigation.add(:products, label: 'Products', position: 20)
      navigation.move(:products, before: :dashboard)

      products = navigation.find(:products)
      dashboard = navigation.find(:dashboard)

      expect(products.position).to be < dashboard.position
    end

    it 'moves item after another' do
      navigation.add(:dashboard, label: 'Dashboard', position: 10)
      navigation.add(:products, label: 'Products', position: 20)
      navigation.move(:dashboard, after: :products)

      dashboard = navigation.find(:dashboard)
      products = navigation.find(:products)

      expect(dashboard.position).to be > products.position
    end
  end

  describe '#root_items' do
    it 'returns items without parent' do
      navigation.add(:dashboard, label: 'Dashboard')
      navigation.add(:products, label: 'Products') do |nav|
        nav.add(:all_products, label: 'All Products')
      end

      root_items = navigation.root_items

      expect(root_items.size).to eq(2)
      expect(root_items.map(&:key)).to contain_exactly(:dashboard, :products)
    end

    it 'returns items sorted by position' do
      navigation.add(:products, label: 'Products', position: 20)
      navigation.add(:dashboard, label: 'Dashboard', position: 10)

      root_items = navigation.root_items

      expect(root_items.first.key).to eq(:dashboard)
      expect(root_items.last.key).to eq(:products)
    end
  end

  describe '#visible_items' do
    it 'returns all items when no conditions' do
      navigation.add(:dashboard, label: 'Dashboard')
      navigation.add(:products, label: 'Products')

      visible = navigation.visible_items(nil)

      expect(visible.size).to eq(2)
    end

    it 'filters items based on condition with view context' do
      context = Object.new
      def context.admin?
        true
      end

      navigation.add(:dashboard, label: 'Dashboard')
      navigation.add(:admin_panel, label: 'Admin', if: -> { admin? })
      navigation.add(:restricted, label: 'Restricted', if: -> { false })

      visible = navigation.visible_items(context)

      expect(visible.map(&:key)).to contain_exactly(:dashboard, :admin_panel)
    end
  end

  describe '#section' do
    it 'creates a section header' do
      section = navigation.section(:main, label: 'Main Section')

      expect(section.section?).to be true
      expect(section.section_label).to eq('Main Section')
    end

    it 'supports block for section items' do
      navigation.section(:main, label: 'Main Section') do |nav|
        nav.add(:dashboard, label: 'Dashboard')
        nav.add(:products, label: 'Products')
      end

      section = navigation.find(:main)
      expect(section.children.size).to eq(2)
    end
  end

  describe '#clear' do
    it 'removes all items' do
      navigation.add(:dashboard, label: 'Dashboard')
      navigation.add(:products, label: 'Products')
      navigation.clear

      expect(navigation.root_items).to be_empty
    end
  end
end
