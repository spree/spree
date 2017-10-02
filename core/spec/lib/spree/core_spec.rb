require 'spec_helper'

describe Spree do
  describe '.admin_path' do
    it { expect(Spree.admin_path).to eq(Spree::Config[:admin_path]) }
  end

  describe '.admin_path=' do
    let!(:original_admin_path) { Spree.admin_path }
    let(:new_admin_path) { '/admin-secret-path' }

    before do
      Spree.admin_path = new_admin_path
    end

    it { expect(Spree.admin_path).to eq(new_admin_path) }
    it { expect(Spree::Config[:admin_path]).to eq(new_admin_path) }

    after do
      Spree.admin_path = original_admin_path
    end
  end

  describe '.user_class' do
    context 'when user_class is a Class instance' do
      it 'raises an error' do
        Spree.user_class = Spree::LegacyUser

        expect { Spree.user_class }.to raise_error(RuntimeError)
      end
    end

    context 'when user_class is a Symbol instance' do
      it 'returns the user_class constant' do
        Spree.user_class = :'Spree::LegacyUser'

        expect(Spree.user_class).to eq(Spree::LegacyUser)
      end
    end

    context 'when user_class is a String instance' do
      it 'returns the user_class constant' do
        Spree.user_class = 'Spree::LegacyUser'

        expect(Spree.user_class).to eq(Spree::LegacyUser)
      end
    end

    context 'when constantize is false' do
      it 'returns the user_class as a String' do
        Spree.user_class = 'Spree::LegacyUser'

        expect(Spree.user_class(constantize: false)).to eq('Spree::LegacyUser')
      end
    end

    after do
      Spree.user_class = 'Spree::LegacyUser'
    end
  end
end
