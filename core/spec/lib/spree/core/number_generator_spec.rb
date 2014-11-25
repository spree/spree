require 'spec_helper'

describe Spree::Core::NumberGenerator do
  let(:number_generator) { described_class.new(options) }
  let(:random)           { instance_double(Random)      }

  let(:model) do
    mod = number_generator

    Class.new(ActiveRecord::Base) do
      self.table_name = 'spree_orders'
      include mod
    end
  end

  before do
    expect(Random).to receive(:new).and_return(random)
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
        expect { object.public_send(:"#{name}=", value_b) }
          .to change { object.public_send(name) }
          .from(value_a)
          .to(value_b)
      end
    end
  end

  shared_examples_for 'duplicate without length increment' do
    before do
      expect(random).to receive(:rand).
        with(expected_rand_limit).
        and_return(next_candidate_index).
        exactly(expected_length).times
    end

    it 'sets permalink field' do
      expect { subject }.to change(resource, :number).from(nil).to(next_candidate)
    end
  end

  shared_examples_for 'generating permalink'do
    let(:resource) { model.new }

    before do
      expect(random).to receive(:rand).
        with(expected_rand_limit).
        and_return(first_candidate_index).
        exactly(expected_length).times
    end

    context 'and generated candidate is unique' do
      before do
        expect(model).to receive(:exists?).with(number: first_candidate).and_return(false)
      end

      it 'sets permalink field' do
        expect { subject }.to change(resource, :number).from(nil).to(first_candidate)
      end
    end

    context 'and generated candidate is NOT unique' do
      before do
        expect(model).to receive(:exists?).with(number: first_candidate).and_return(true).ordered
        expect(model).to receive(:count).and_return(record_count).ordered
        expect(model).to receive(:exists?).with(number: next_candidate).and_return(false)
      end

      context 'and less than half of the value space taken' do
        let(:next_candidate) { next_candidate_low            }
        let(:record_count)   { 10 ** expected_length / 2 - 1 }

        include_examples 'duplicate without length increment'
      end

      context 'and exactly half of the value space taken' do
        let(:next_candidate) { next_candidate_low        }
        let(:record_count)   { 10 ** expected_length / 2 }

        include_examples 'duplicate without length increment'
      end

      context 'and more than half of the value space is taken' do
        let(:record_count)   { 10 ** expected_length / 2 + 1 }
        let(:next_candidate) { next_candidate_high           }

        before do
          expect(random).to receive(:rand).
            with(expected_rand_limit).
            and_return(next_candidate_index).
            exactly(expected_length.succ).times
        end

        it 'sets permalink field' do
          expect { subject }.to change(resource, :number).from(nil).to(next_candidate)
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

      let(:first_candidate_index) { 0  }
      let(:next_candidate_index)  { 1  }
      let(:expected_rand_limit)   { 10 }
      let(:expected_length)       { 9  }

      context 'when permalink field value is nil' do
        context 'on defaults' do
          let(:first_candidate)     { 'R000000000'  }
          let(:next_candidate_low)  { 'R111111111'  }
          let(:next_candidate_high) { 'R1111111111' }

          include_examples 'generating permalink'
        end

        context 'with length: option' do
          let(:options)         { super().merge(length: 10) }
          let(:expected_length) { 10 }

          let(:first_candidate)     { 'R0000000000'  }
          let(:next_candidate_low)  { 'R1111111111'  }
          let(:next_candidate_high) { 'R11111111111' }

          include_examples 'generating permalink'
        end

        context 'with letters option' do
          let(:options)             { super().merge(letters: true) }
          let(:expected_rand_limit) { 36                           }

          let(:first_candidate)       { 'RAAAAAAAAA'  }
          let(:first_candidate_index) { 10            }
          let(:next_candidate_index)  { 11            }
          let(:next_candidate_low)    { 'RBBBBBBBBB'  }
          let(:next_candidate_high)   { 'RBBBBBBBBBB' }

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
