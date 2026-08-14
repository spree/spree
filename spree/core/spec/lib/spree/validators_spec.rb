require 'spec_helper'

RSpec.describe Spree::Validators do
  let(:registry) { described_class.new }

  # Extensions have always read this as a plain array of classes.
  it 'behaves like an array of validator classes' do
    registry.addresses = [Spree::Addresses::PhoneValidator]

    expect(registry.addresses).to be_an(Array)
    expect(registry.addresses).to eq([Spree::Addresses::PhoneValidator])
  end

  it 'registers a validator by class or name' do
    registry.addresses.register('Spree::Addresses::PhoneValidator')

    expect(registry.addresses).to eq([Spree::Addresses::PhoneValidator])
  end

  it 'ignores a validator already registered' do
    2.times { registry.addresses.register(Spree::Addresses::PhoneValidator) }

    expect(registry.addresses.size).to eq(1)
  end

  # The point of the registry: dropping a rule core ships.
  it 'unregisters a validator' do
    registry.addresses.register(Spree::Addresses::PhoneValidator)

    expect(registry.addresses.unregister(Spree::Addresses::PhoneValidator)).to eq(Spree::Addresses::PhoneValidator)
    expect(registry.addresses).to be_empty
  end

  it 'returns nil when unregistering something never registered' do
    expect(registry.addresses.unregister(Spree::Addresses::PhoneValidator)).to be_nil
  end
end

RSpec.describe 'Spree.validators.addresses' do
  around do |example|
    original = Spree.validators.addresses.dup
    example.run
    Spree.validators.addresses.replace(original)
  end

  it 'ships the phone validator by default' do
    expect(Spree.validators.addresses).to include(Spree::Addresses::PhoneValidator)
  end

  it 'runs a registered validator against addresses' do
    stub_const('SpecPostBoxValidator', Class.new(ActiveModel::Validator) do
      def validate(record)
        record.errors.add(:address1, 'cannot be a PO box') if record.address1.to_s.match?(/\APO Box/i)
      end
    end)
    Spree.validators.addresses.register(SpecPostBoxValidator)

    address = build(:address, address1: 'PO Box 123')

    expect(address).not_to be_valid
    expect(address.errors['address1']).to include('cannot be a PO box')
  end
end
