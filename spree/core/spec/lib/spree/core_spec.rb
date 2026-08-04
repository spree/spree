require 'spec_helper'

describe Spree do
  describe '.customer_class' do
    after do
      described_class.customer_class = 'Spree::Customer'
    end

    context 'when customer_class is a Class instance' do
      it 'raises an error' do
        described_class.customer_class = Spree::Customer

        expect { described_class.customer_class }.to raise_error(RuntimeError)
      end
    end

    context 'when customer_class is a Symbol instance' do
      it 'returns the customer_class constant' do
        described_class.customer_class = :'Spree::Customer'

        expect(described_class.customer_class).to eq(Spree::Customer)
      end
    end

    context 'when customer_class is a String instance' do
      it 'returns the customer_class constant' do
        described_class.customer_class = 'Spree::Customer'

        expect(described_class.customer_class).to eq(Spree::Customer)
      end
    end

    context 'when constantize is false' do
      it 'returns the customer_class as a String' do
        described_class.customer_class = 'Spree::Customer'

        expect(described_class.customer_class(constantize: false)).to eq('Spree::Customer')
      end
    end
  end

  describe '.user_class (deprecated alias for .customer_class)' do
    after do
      described_class.customer_class = 'Spree::Customer'
    end

    it 'delegates reads and writes to customer_class' do
      described_class.user_class = 'Spree::Customer'

      expect(described_class.user_class).to eq(Spree::Customer)
      expect(described_class.customer_class).to eq(Spree::Customer)
    end
  end

  describe '.admin_user_class' do
    after do
      described_class.admin_user_class = 'Spree::AdminUser'
    end

    context 'when admin_user_class is a Class instance' do
      it 'raises an error' do
        described_class.admin_user_class = Spree::AdminUser

        expect { described_class.admin_user_class }.to raise_error(RuntimeError)
      end
    end

    context 'when admin_user_class is a Symbol instance' do
      it 'returns the admin_user_class constant' do
        described_class.admin_user_class = :'Spree::AdminUser'

        expect(described_class.admin_user_class).to eq(Spree::AdminUser)
      end
    end

    context 'when admin_user_class is a String instance' do
      it 'returns the admin_user_class constant' do
        described_class.admin_user_class = 'Spree::AdminUser'

        expect(described_class.admin_user_class).to eq(Spree::AdminUser)
      end
    end

    context 'when constantize is false' do
      it 'returns the admin_user_class as a String' do
        described_class.admin_user_class = 'Spree::AdminUser'

        expect(described_class.admin_user_class(constantize: false)).to eq('Spree::AdminUser')
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

    context 'when private_storage_service_name is set to nil' do
      it 'returns the private_storage_service_name as the default service' do
        described_class.private_storage_service_name = nil

        expect(described_class.private_storage_service_name).to eq(Rails.application.config.active_storage.service)
      end
    end
  end

  describe '.install_id' do
    let(:store) { Spree::Preferences::Store.instance }

    around do |example|
      store.delete('spree/install_id')
      example.run
      store.delete('spree/install_id')
    end

    it 'generates a UUID, persists it and returns the same value on subsequent calls' do
      id = described_class.install_id

      expect(id).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
      expect(store.get('spree/install_id') { nil }).to eq(id)
      expect(described_class.install_id).to eq(id)
    end

    it 'reuses an identifier already persisted in the preferences store' do
      store.set('spree/install_id', 'already-persisted-id')

      expect(described_class.install_id).to eq('already-persisted-id')
    end
  end

end
