require 'spec_helper'

RSpec.describe Spree::RemovedApis do
  def hint_for(&block)
    block.call
    raise 'expected an error'
  rescue NameError => e
    e.detailed_message
  end

  it 'names the replacement for a removed instance method' do
    message = hint_for { Spree::Order.new.next }

    expect(message).to include('Spree 6.0 removed Spree::Order#next.')
    expect(message).to include('carts_complete_workflow')
    expect(message).to include(described_class::UPGRADE_GUIDES.fetch('6.0'))
  end

  it 'names the replacement for a removed class method' do
    expect(hint_for { Spree::Order.checkout_flow }).to include('Spree::Checkout::Registry.add_requirement')
  end

  it 'names the replacement for a removed class method called on a relation' do
    expect(hint_for { Spree::Product.all.with_option('color') }).to include('Spree 6.0 removed Spree::Product.with_option. Use with_option_value.')
  end

  it 'names the replacement for a removed constant' do
    expect(hint_for { Spree::ReturnAuthorization }).to include('Spree 6.0 removed Spree::ReturnAuthorization.')
  end

  it 'names the replacement for a receiverless call, as in a decorator' do
    order = Spree::Order.new

    expect(hint_for { order.instance_eval { adjustments } }).to include('Spree 6.0 removed Spree::Order#adjustments.')
  end

  it 'does not mistake a missing nested constant for a removed top-level one' do
    stub_const('Spree::Reporting::Example', Module.new)

    message = hint_for { Spree::Reporting::Example::Report }

    expect(message).not_to include('Spree 6.0 removed')
  end

  it 'has an upgrade guide for every release' do
    expect(described_class::REMOVED.keys - described_class::UPGRADE_GUIDES.keys).to be_empty
  end

  it 'matches subclasses of the class a method was removed from' do
    subclass = Class.new(Spree::Variant)

    expect(hint_for { subclass.new.price }).to include('price_in(currency).amount')
  end

  it 'leaves other errors alone' do
    message = hint_for { Spree::Order.new.not_a_spree_method }

    expect(message).not_to include('Spree 6.0 removed')
  end

  it 'leaves the error class, message and respond_to? unchanged' do
    variant = Spree::Variant.new

    expect { variant.price }.to raise_error(NoMethodError) { |error| expect(error.message).not_to include('Spree 6.0') }
    expect(variant.respond_to?(:price)).to be(false)
    expect(variant.try(:price)).to be_nil
  end

  it 'never hints at a name that still exists' do
    still_defined = described_class::REMOVED.values.flat_map(&:keys).select do |key|
      if (match = key.match(/\A(?<owner>[\w:]+)#(?<name>.+)\z/))
        owner = match[:owner].constantize
        owner.method_defined?(match[:name]) || owner.private_method_defined?(match[:name]) ||
          (owner < ActiveRecord::Base && owner.attribute_names.include?(match[:name].delete_suffix('=')))
      elsif (match = key.match(/\A(?<owner>[\w:]+)\.(?<name>.+)\z/))
        match[:owner].constantize.respond_to?(match[:name], true)
      else
        begin
          Object.const_get(key)
          true
        rescue NameError
          false
        end
      end
    end

    expect(still_defined).to be_empty
  end
end
