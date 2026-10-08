require 'spec_helper'

RSpec.describe Spree::ApiTyped do
  let(:base) { Class.new { extend Spree::ApiTyped } }

  def named(class_name)
    Class.new(base).tap { |klass| klass.define_singleton_method(:name) { class_name } }
  end

  describe '#api_type' do
    it 'uses the leaf inside a Spree family' do
      expect(named('Spree::FulfillmentProvider::Manual').api_type).to eq('manual')
      expect(named('Spree::OrderRouting::Strategy::Rules').api_type).to eq('rules')
    end

    it "uses the gem's module for a class named after its family" do
      expect(named('SpreeEasyPost::FulfillmentProvider').api_type).to eq('easy_post')
      expect(named('SpreeStripe::PayoutProvider').api_type).to eq('stripe')
      expect(named('SpreeAcmeOms::Strategy').api_type).to eq('acme_oms')
    end
  end

  describe '.find / .class_name_for / .api_type_for' do
    let(:registry) { [Spree::FulfillmentProvider::Manual, Spree::FulfillmentProvider::Digital] }

    it 'round-trips a registered class' do
      expect(described_class.find(registry, 'digital')).to eq(Spree::FulfillmentProvider::Digital)
      expect(described_class.class_name_for(registry, 'manual')).to eq('Spree::FulfillmentProvider::Manual')
      expect(described_class.api_type_for('Spree::FulfillmentProvider::Manual')).to eq('manual')
    end

    it 'never resolves a class name or an unregistered shorthand' do
      expect(described_class.find(registry, 'Spree::FulfillmentProvider::Manual')).to be_nil
      expect(described_class.find(registry, 'pickup')).to be_nil
      expect(described_class.class_name_for(registry, 'nope')).to eq('nope')
    end

    it 'shortens an unloadable stored class name' do
      expect(described_class.api_type_for('SpreeGone::Provider::Thing')).to eq('thing')
    end
  end
end
