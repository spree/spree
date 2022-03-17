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

  describe '.private_storage_service_name' do
    after do
      described_class.private_storage_service_name = nil
    end

    context 'when private_storage_service_name is a Symbol instance' do
      it 'returns the private_storage_service_name as a symbol' do
        described_class.private_storage_service_name = :my_secret_asset_store

        expect(described_class.private_storage_service_name).to eq(:my_secret_asset_store)
      end
    end

    context 'when private_storage_service_name is a String instance' do
      it 'returns the private_storage_service_name as a symbol' do
        described_class.private_storage_service_name = 'my_hidden_asset_store'

        expect(described_class.private_storage_service_name).to eq(:my_hidden_asset_store)
      end
    end

    context 'when private_storage_service_name is a Integer instance' do
      it 'raises an error' do
        described_class.private_storage_service_name = 33

        expect { described_class.private_storage_service_name }.to raise_error(RuntimeError)
      end
    end

    context 'when private_storage_service_name is set to nil' do
      it 'returns the private_storage_service_name as nil value' do
        described_class.private_storage_service_name = nil

        expect(described_class.private_storage_service_name).to be nil
      end
    end
  end

  describe '.searcher_class' do
    after do
      described_class.searcher_class = 'Spree::Core::Search::Base'
    end

    context 'when searcher_class is a Class instance' do
      it 'raises an error' do
        described_class.searcher_class = Spree::Core::Search::Base

        expect { described_class.searcher_class }.to raise_error(RuntimeError)
      end
    end

    context 'when searcher_class is a Symbol instance' do
      it 'returns the searcher_class constant' do
        described_class.searcher_class = :'Spree::Core::Search::Base'

        expect(described_class.searcher_class).to eq(Spree::Core::Search::Base)
      end
    end

    context 'when searcher_class is a String instance' do
      it 'returns the searcher_class constant' do
        described_class.searcher_class = 'Spree::Core::Search::Base'

        expect(described_class.searcher_class).to eq(Spree::Core::Search::Base)
      end
    end

    context 'when constantize is false' do
      it 'returns the searcher_class as a String' do
        described_class.searcher_class = 'Spree::Core::Search::Base'

        expect(described_class.searcher_class(constantize: false)).to eq('Spree::Core::Search::Base')
      end
    end
  end
end
