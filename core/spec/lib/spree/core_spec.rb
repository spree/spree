require 'spec_helper'

describe Spree do
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

  describe '.admin_user_class' do
    after do
      described_class.admin_user_class = nil
    end

    context 'when admin_user_class is nil' do
      it 'fallbacks to user_class' do
        described_class.user_class = 'Spree::LegacyUser'

        expect(described_class.admin_user_class).to eq(Spree::LegacyUser)
      end
    end

    context 'when admin_user_class is a Class instance' do
      it 'raises an error' do
        described_class.admin_user_class = Spree::LegacyUser

        expect { described_class.admin_user_class }.to raise_error(RuntimeError)
      end
    end

    context 'when admin_user_class is a Symbol instance' do
      it 'returns the admin_user_class constant' do
        described_class.admin_user_class = :'Spree::LegacyUser'

        expect(described_class.admin_user_class).to eq(Spree::LegacyUser)
      end
    end

    context 'when admin_user_class is a String instance' do
      it 'returns the admin_user_class constant' do
        described_class.admin_user_class = 'Spree::LegacyUser'

        expect(described_class.admin_user_class).to eq(Spree::LegacyUser)
      end
    end

    context 'when constantize is false' do
      it 'returns the admin_user_class as a String' do
        described_class.admin_user_class = 'Spree::LegacyUser'

        expect(described_class.admin_user_class(constantize: false)).to eq('Spree::LegacyUser')
      end
    end
  end
end
