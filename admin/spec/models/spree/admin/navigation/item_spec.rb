require 'spec_helper'

RSpec.describe Spree::Admin::Navigation::Item do
  describe '#initialize' do
    it 'creates an item with basic attributes' do
      item = described_class.new(:dashboard, label: 'Dashboard', url: '/admin', icon: 'home')

      expect(item.key).to eq(:dashboard)
      expect(item.label).to eq('Dashboard')
      expect(item.url).to eq('/admin')
      expect(item.icon).to eq('home')
    end

    it 'sets default position to 999' do
      item = described_class.new(:dashboard)

      expect(item.position).to eq(999)
    end

    it 'accepts custom position' do
      item = described_class.new(:dashboard, position: 10)

      expect(item.position).to eq(10)
    end

    it 'accepts active condition' do
      item = described_class.new(:dashboard, active: -> { true })

      expect(item.active_condition).to be_a(Proc)
    end

    it 'accepts tooltip' do
      item = described_class.new(:dashboard, tooltip: 'Dashboard page')

      expect(item.tooltip).to eq('Dashboard page')
    end

    it 'initializes empty children array' do
      item = described_class.new(:dashboard)

      expect(item.children).to eq([])
    end
  end

  describe '#visible?' do
    it 'returns true when no condition is set' do
      item = described_class.new(:dashboard)

      expect(item.visible?(nil)).to be true
    end

    it 'evaluates proc condition with view context' do
      item = described_class.new(:dashboard, if: -> { can?(:manage, :dashboard) })

      context = Object.new
      def context.can?(action, subject)
        action == :manage && subject == :dashboard
      end

      expect(item.visible?(context)).to be true
    end

    it 'evaluates boolean condition' do
      item_true = described_class.new(:dashboard, if: true)
      expect(item_true.visible?(nil)).to be true

      item_false = described_class.new(:dashboard, if: false)
      expect(item_false.visible?(nil)).to be false
    end

    it 'evaluates proc without view context' do
      item = described_class.new(:dashboard, if: -> { true })

      expect(item.visible?(nil)).to be true
    end
  end

  describe '#active?' do
    let(:item) { described_class.new(:dashboard, url: '/admin/dashboard') }

    it 'uses active condition when provided' do
      item = described_class.new(:dashboard, url: '/admin/dashboard', active: -> { controller_name == 'dashboard' })

      context = Object.new
      def context.controller_name
        'dashboard'
      end

      expect(item.active?('/admin/dashboard', context)).to be true
    end

    it 'returns true for exact path match' do
      context = double('ViewContext')
      allow(context).to receive(:spree).and_return(double('Routes'))

      expect(item.active?('/admin/dashboard', context)).to be true
    end

    it 'returns true when path starts with item url' do
      context = double('ViewContext')
      allow(context).to receive(:spree).and_return(double('Routes'))

      expect(item.active?('/admin/dashboard/stats', context)).to be true
    end

    it 'returns false for non-matching path' do
      context = double('ViewContext')
      allow(context).to receive(:spree).and_return(double('Routes'))

      expect(item.active?('/admin/products', context)).to be false
    end

    it 'evaluates active condition in view context' do
      item = described_class.new(:orders, active: -> { %w[orders checkouts].include?(controller_name) })

      context = Object.new
      def context.controller_name
        'orders'
      end

      expect(item.active?('/admin/orders', context)).to be true
    end
  end

  describe '#resolve_url' do
    it 'returns string url as is' do
      item = described_class.new(:dashboard, url: '/admin')

      expect(item.resolve_url(nil)).to eq('/admin')
    end

    it 'calls proc url in view context' do
      item = described_class.new(:dashboard, url: -> { spree.admin_path })

      context = Object.new
      spree_routes = Object.new
      def spree_routes.admin_path
        '/admin'
      end
      def context.spree
        @spree_routes
      end
      context.instance_variable_set(:@spree_routes, spree_routes)

      expect(item.resolve_url(context)).to eq('/admin')
    end

    it 'calls symbol url with view context' do
      item = described_class.new(:dashboard, url: :admin_path)

      context = double('ViewContext')
      spree_routes = double('Routes', admin_path: '/admin')
      allow(context).to receive(:spree).and_return(spree_routes)

      expect(item.resolve_url(context)).to eq('/admin')
    end

    it 'handles proc url without context' do
      item = described_class.new(:dashboard, url: -> { '/admin/fallback' })

      expect(item.resolve_url(nil)).to eq('/admin/fallback')
    end
  end

  describe '#resolve_label' do
    it 'uses Spree.t for translation' do
      allow(Spree).to receive(:t).with(:dashboard, default: 'Dashboard').and_return('Dashboard')

      item = described_class.new(:dashboard, label: :dashboard)

      expect(item.resolve_label).to eq('Dashboard')
    end

    it 'translates string labels' do
      allow(Spree).to receive(:t).with('admin.dashboard', default: 'Admin.dashboard').and_return('Dashboard')

      item = described_class.new(:dashboard, label: 'admin.dashboard')

      expect(item.resolve_label).to eq('Dashboard')
    end
  end

  describe '#badge_value' do
    it 'returns nil when no badge is set' do
      item = described_class.new(:dashboard)

      expect(item.badge_value(nil)).to be_nil
    end

    it 'calls proc badge with view context' do
      item = described_class.new(:orders, badge: -> { ready_to_ship_orders_count })

      context = Object.new
      def context.ready_to_ship_orders_count
        5
      end

      expect(item.badge_value(context)).to eq(5)
    end

    it 'returns static badge value' do
      item = described_class.new(:orders, badge: 'Enterprise')

      expect(item.badge_value(nil)).to eq('Enterprise')
    end

    it 'calls proc badge without context' do
      item = described_class.new(:orders, badge: -> { 10 })

      expect(item.badge_value(nil)).to eq(10)
    end
  end

  describe '#section?' do
    it 'returns true when section_label is present' do
      item = described_class.new(:section1, section_label: 'Section 1')

      expect(item.section?).to be true
    end

    it 'returns false when section_label is not present' do
      item = described_class.new(:dashboard)

      expect(item.section?).to be false
    end
  end

  describe '#add_child' do
    it 'adds a child item' do
      parent = described_class.new(:products)
      child = described_class.new(:all_products)

      parent.add_child(child)

      expect(parent.children).to include(child)
      expect(child.parent_key).to eq(:products)
    end

    it 'sorts children by position' do
      parent = described_class.new(:products)
      child1 = described_class.new(:child1, position: 20)
      child2 = described_class.new(:child2, position: 10)

      parent.add_child(child1)
      parent.add_child(child2)

      expect(parent.children.first.key).to eq(:child2)
      expect(parent.children.last.key).to eq(:child1)
    end
  end

  describe '#remove_child' do
    it 'removes a child item by key' do
      parent = described_class.new(:products)
      child = described_class.new(:all_products)

      parent.add_child(child)
      parent.remove_child(:all_products)

      expect(parent.children).to be_empty
    end
  end
end
