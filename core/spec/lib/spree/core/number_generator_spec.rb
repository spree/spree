require 'spec_helper'

describe Spree::Core::NumberGenerator do
  let(:number_generator) { described_class.new(options) }

  let(:model) do
    mod = number_generator

    Class.new(ApplicationRecord) do
      self.table_name = 'spree_orders'
      include mod
    end
  end

  let(:options) { { prefix: 'R' } }

  %i[prefix length].each do |name|
    describe "##{name}" do
      let(:value) { double('Generic Value') }

      it 'returns attribute value from options' do
        expect(described_class.new(options.merge(name => value)).public_send(name)).to be(value)
      end
    end

    describe "##{name}=" do
      let(:value_a) { double('Generic Value A') }
      let(:value_b) { double('Generic Value B') }

      it 'writes attribute value' do
        object = described_class.new(options.merge(name => value_a))
        expect { object.public_send(:"#{name}=", value_b) }.
          to change { object.public_send(name) }.
          from(value_a).
          to(value_b)
      end
    end
  end

  shared_examples_for 'duplicate without length increment' do
    it 'sets permalink field' do
      expect { subject }.to change(resource, :number).from(nil).to(String)
      expect(resource.number).to match(regex)
    end
  end

  shared_examples_for 'generating permalink' do
    let(:resource) { model.new }

    context 'and generated candidate is unique' do
      before do
        expect(model).to receive(:exists?).and_return(false)
      end

      it 'sets permalink field' do
        expect { subject }.to change(resource, :number).from(nil).to(String)
        expect(resource.number).to match(regex)
      end
    end

    context 'and generated candidate is NOT unique' do
      before do
        expect(model).to receive(:exists?).and_return(true).ordered
        expect(model).to receive(:count).and_return(record_count).ordered
        expect(model).to receive(:exists?).and_return(false)
      end

      context 'and less than half of the value space taken' do
        let(:record_count)   { 10**expected_length / 2 - 1 }

        include_examples 'duplicate without length increment'
      end

      context 'and exactly half of the value space taken' do
        let(:record_count) { 10**expected_length / 2 }

        include_examples 'duplicate without length increment'
      end

      context 'and more than half of the value space is taken' do
        let(:record_count)   { 10**expected_length / 2 + 1 }

        it 'sets permalink field' do
          expect { subject }.to change(resource, :number).from(nil).to(String)
          expect(resource.number).to match(regex_more_than_half)
        end
      end
    end
  end

  describe '#included' do
    context 'generates .number_generator on host' do
      it 'returns number generator' do
        expect(model.number_generator).to be(number_generator)
      end
    end

    context 'generates validation hooks on host' do
      subject { resource.valid? }

      let(:expected_length)      { 9 }
      let(:regex)                { /R[0-9]{9}$/  }
      let(:regex_more_than_half) { /R[0-9]{10}$/ }

      context 'when permalink field value is nil' do
        context 'on defaults' do
          include_examples 'generating permalink'
        end

        context 'with length: option' do
          let(:options)              { super().merge(length: 10) }
          let(:expected_length)      { 10 }
          let(:regex)                { /R[0-9]{10}$/ }
          let(:regex_more_than_half) { /R[0-9]{11}$/ }

          include_examples 'generating permalink'
        end

        context 'with letters option' do
          let(:options)              { super().merge(letters: true) }
          let(:regex)                { /R[0-9A-Z]{9}$/  }
          let(:regex_more_than_half) { /R[0-9A-Z]{10}$/ }

          include_examples 'generating permalink'
        end
      end

      context 'when permalink field value is present' do
        let(:resource) { model.new(number: 'Test') }

        it 'does not touch field' do
          expect { subject }.not_to change(resource, :number)
        end
      end
    end
  end
end
