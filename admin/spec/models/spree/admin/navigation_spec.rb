require 'spec_helper'

RSpec.describe Spree::Admin::Navigation do
  after do
    # Clear all registries after each test
    described_class.clear_all!
  end

  describe '.configure' do
    it 'configures navigation for a context' do
      described_class.configure(:sidebar) do |nav|
        nav.add :dashboard, label: 'Dashboard', url: '/admin'
      end

      expect(described_class.find(:dashboard)).not_to be_nil
    end

    it 'supports multiple contexts' do
      described_class.configure(:sidebar) do |nav|
        nav.add :dashboard, label: 'Dashboard'
      end

      described_class.configure(:settings) do |nav|
        nav.add :general, label: 'General'
      end

      expect(described_class.registry(:sidebar).find(:dashboard)).not_to be_nil
      expect(described_class.registry(:settings).find(:general)).not_to be_nil
      expect(described_class.registry(:sidebar).find(:general)).to be_nil
    end
  end

  describe '.registry' do
    it 'creates a new registry for a context' do
      registry = described_class.registry(:custom)

      expect(registry).to be_a(Spree::Admin::Navigation::Registry)
      expect(registry.context).to eq(:custom)
    end

    it 'returns the same registry for the same context' do
      registry1 = described_class.registry(:sidebar)
      registry2 = described_class.registry(:sidebar)

      expect(registry1).to equal(registry2)
    end
  end

  describe '.for' do
    it 'returns registry for context' do
      registry = described_class.for(:sidebar)

      expect(registry).to be_a(Spree::Admin::Navigation::Registry)
    end
  end

  describe 'delegation to default registry' do
    it 'delegates add to sidebar registry' do
      described_class.add(:dashboard, label: 'Dashboard')

      expect(described_class.registry(:sidebar).find(:dashboard)).not_to be_nil
    end

    it 'delegates remove to sidebar registry' do
      described_class.add(:dashboard, label: 'Dashboard')
      described_class.remove(:dashboard)

      expect(described_class.find(:dashboard)).to be_nil
    end

    it 'delegates update to sidebar registry' do
      described_class.add(:dashboard, label: 'Dashboard')
      described_class.update(:dashboard, label: 'Home')

      item = described_class.find(:dashboard)
      expect(item.label).to eq('Home')
    end

    it 'delegates find to sidebar registry' do
      item = described_class.add(:dashboard, label: 'Dashboard')

      expect(described_class.find(:dashboard)).to eq(item)
    end

    it 'delegates exists? to sidebar registry' do
      described_class.add(:dashboard, label: 'Dashboard')

      expect(described_class.exists?(:dashboard)).to be true
      expect(described_class.exists?(:nonexistent)).to be false
    end
  end

  describe '.visible_items' do
    it 'returns visible items for context with view context' do
      described_class.configure(:sidebar) do |nav|
        nav.add :dashboard, label: 'Dashboard'
        nav.add :admin, label: 'Admin', if: -> { admin? }
      end

      context = Object.new
      def context.admin?
        true
      end
      items = described_class.visible_items(:sidebar, context)

      expect(items.map(&:key)).to contain_exactly(:dashboard, :admin)
    end
  end

  describe '.contexts' do
    it 'returns all registered contexts' do
      described_class.registry(:sidebar)
      described_class.registry(:settings)
      described_class.registry(:custom)

      expect(described_class.contexts).to contain_exactly(:sidebar, :settings, :custom)
    end
  end

  describe '.clear_all!' do
    it 'clears all registries' do
      described_class.add(:dashboard, label: 'Dashboard')
      described_class.for(:settings).add(:general, label: 'General')

      described_class.clear_all!

      expect(described_class.registries).to be_empty
    end
  end

  describe '.clear!' do
    it 'clears specific registry' do
      described_class.add(:dashboard, label: 'Dashboard')
      described_class.for(:settings).add(:general, label: 'General')

      described_class.clear!(:sidebar)

      expect(described_class.find(:dashboard)).to be_nil
      expect(described_class.for(:settings).find(:general)).not_to be_nil
    end
  end
end
