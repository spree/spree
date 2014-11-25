require 'spec_helper'

describe Spree::Core::Permalinks do
  let(:model) do
    options = options().freeze

    Class.new(ActiveRecord::Base) do
      self.table_name = 'spree_orders'
      include Spree::Core::Permalinks.new(options)
    end
  end

  let(:options) { { prefix: 'R' } }

  shared_examples_for 'duplicate without length increment' do
    let(:next_candidate) { next_candidate_low }

    before do
      expect(Spree::Core::Permalinks::RAND).to receive(:rand)
        .with(10 ** expected_length)
        .and_return(next_candidate_number)

      expect(model).to receive(:exists?).with(number: next_candidate).and_return(false).ordered
    end

    it 'sets permalink field' do
      expect { subject }.to change { resource.number }.from(nil).to(next_candidate)
    end
  end

  shared_examples_for 'generating permalink'do
    let(:resource) { model.new }

    before do
      expect(Spree::Core::Permalinks::RAND).to receive(:rand)
        .with(10 ** expected_length)
        .and_return(0)
    end

    context 'and generated candidate is unique' do
      before do
        expect(model).to receive(:exists?).with(number: candidate).and_return(false)
      end

      it 'sets permalink field' do
        expect { subject }.to change { resource.number }.from(nil).to(candidate)
      end
    end

    context 'and generated candidate is NOT unique' do
      before do
        expect(model).to receive(:exists?).with(number: candidate).and_return(true).ordered
        expect(model).to receive(:count).and_return(record_count).ordered
      end

      let(:next_candidate_number) { 1 }

      context 'and less than half of the value space taken' do
        let(:record_count) { 10 ** expected_length / 2 - 1 }

        include_examples 'duplicate without length increment'
      end

      context 'and exactly half of the value space taken' do
        let(:record_count) { 10 ** expected_length / 2 }

        include_examples 'duplicate without length increment'
      end

      context 'and more than half of the value space is taken' do
        let(:record_count)   { 10 ** expected_length / 2 + 1 }
        let(:next_candidate) { next_candidate_high           }

        before do
          expect(Spree::Core::Permalinks::RAND).to receive(:rand)
            .with(10 ** expected_length.succ)
            .and_return(next_candidate_number)

          expect(model).to receive(:exists?).with(number: next_candidate).and_return(false).ordered
        end

        it 'sets permalink field' do
          expect { subject }.to change { resource.number }.from(nil).to(next_candidate)
        end
      end
    end
  end

  context 'generated helpers' do
    let(:argument) { double('argument') }
    let(:result)   { double('result')   }

    context 'generated #find_by_param' do
      it 'allows to find fields by permalink' do
        expect(model).to receive(:find_by_number).with(argument).and_return(result)
        expect(model.find_by_param(argument)).to be(result)
      end
    end

    context 'generated #find_by_param!' do
      it 'allows to find fields by permalink' do
        expect(model).to receive(:find_by_number!).with(argument).and_return(result)
        expect(model.find_by_param!(argument)).to be(result)
      end
    end
  end

  context 'generated validation hooks' do
    subject { resource.valid? }

    let(:candidate)           { 'R0000000000'  }
    let(:next_candidate_low)  { 'R0000000001'  }
    let(:next_candidate_high) { 'R00000000001' }

    context 'when permalink field value is nil' do
      context 'with length option' do
        let(:options)         { super().merge(length: 10) }
        let(:expected_length) { 10                        }

        include_examples 'generating permalink'
      end

      context 'without length option' do
        let(:expected_length)     { 9             }
        let(:candidate)           { 'R000000000'  }
        let(:next_candidate_low)  { 'R000000001'  }
        let(:next_candidate_high) { 'R0000000001' }

        include_examples 'generating permalink'
      end
    end

    context 'when permalink field value is present' do
      let(:resource) { model.new(number: 'Test') }

      it 'does not touch field' do
        expect { subject }.not_to change { resource.number }
      end
    end
  end
end
