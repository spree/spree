require 'spec_helper'

RSpec.describe Spree::PaymentResponse do
  describe '#initialize' do
    context 'with minimal arguments' do
      subject { described_class.new(true, 'Success') }

      it 'sets success, message and defaults' do
        expect(subject).to be_success
        expect(subject.message).to eq('Success')
        expect(subject.params).to eq({})
        expect(subject.test).to be false
        expect(subject.authorization).to be_nil
        expect(subject.avs_result).to eq('code' => nil)
        expect(subject.cvv_result).to eq('code' => nil, 'message' => nil)
      end
    end

    context 'with all options' do
      subject do
        described_class.new(
          true,
          'Approved',
          { 'transaction_id' => 'tx_1' },
          authorization: 'auth_123',
          avs_result: { code: 'D' },
          cvv_result: { code: 'M', message: 'Match' },
          test: true
        )
      end

      it 'stores authorization' do
        expect(subject.authorization).to eq('auth_123')
      end

      it 'stores avs_result with string keys' do
        expect(subject.avs_result).to eq('code' => 'D')
      end

      it 'stores cvv_result with string keys' do
        expect(subject.cvv_result).to eq('code' => 'M', 'message' => 'Match')
      end

      it 'stores test flag' do
        expect(subject).to be_test
      end

      it 'stores params with indifferent access' do
        expect(subject.params[:transaction_id]).to eq('tx_1')
        expect(subject.params['transaction_id']).to eq('tx_1')
      end
    end
  end

  describe '#success?' do
    it 'returns true for a successful response' do
      expect(described_class.new(true, 'ok')).to be_success
    end

    it 'returns false for a failed response' do
      expect(described_class.new(false, 'fail')).not_to be_success
    end
  end

  describe '#test?' do
    it 'returns true when test option is set' do
      expect(described_class.new(true, '', {}, test: true)).to be_test
    end

    it 'returns false by default' do
      expect(described_class.new(true, '')).not_to be_test
    end
  end

  describe 'YAML serialization' do
    it 'round-trips through YAML.safe_load' do
      original = described_class.new(true, 'Captured', { 'ref' => '42' },
                                     authorization: 'auth_1', test: true,
                                     avs_result: { code: 'Y' },
                                     cvv_result: { code: 'M', message: 'Match' })

      yaml = original.to_yaml
      restored = YAML.safe_load(yaml, permitted_classes: [described_class, ActiveSupport::HashWithIndifferentAccess])

      expect(restored).to be_a(described_class)
      expect(restored).to be_success
      expect(restored.message).to eq('Captured')
      expect(restored.authorization).to eq('auth_1')
      expect(restored.params['ref']).to eq('42')
      expect(restored.avs_result['code']).to eq('Y')
      expect(restored.cvv_result['code']).to eq('M')
    end
  end
end
