require 'spec_helper'

describe Spree do
  describe '.admin_path' do
    it { expect(described_class.admin_path).to eq(Spree::Config[:admin_path]) }
  end

  describe '.admin_path=' do
    let!(:original_admin_path) { described_class.admin_path }
    let(:new_admin_path) { '/admin-secret-path' }

    before do
      described_class.admin_path = new_admin_path
    end

    after do
      described_class.admin_path = original_admin_path
    end

    it { expect(described_class.admin_path).to eq(new_admin_path) }
    it { expect(Spree::Config[:admin_path]).to eq(new_admin_path) }
  end

  describe '.user_class' do
    after do
      described_class.user_class = 'Spree::LegacyUser'
    end

    context 'when user_class is a Class instance' do
      it 'raises an error' do
        described_class.user_class = Spree::LegacyUser

        expect { described_class.user_class }.to raise_error(RuntimeError)
      end
    end

    context 'when user_class is a Symbol instance' do
      it 'returns the user_class constant' do
        described_class.user_class = :'Spree::LegacyUser'

        expect(described_class.user_class).to eq(Spree::LegacyUser)
      end
    end

    context 'when user_class is a String instance' do
      it 'returns the user_class constant' do
        described_class.user_class = 'Spree::LegacyUser'

        expect(described_class.user_class).to eq(Spree::LegacyUser)
      end
    end

    context 'when constantize is false' do
      it 'returns the user_class as a String' do
        described_class.user_class = 'Spree::LegacyUser'

        expect(described_class.user_class(constantize: false)).to eq('Spree::LegacyUser')
      end
    end
  end
end
