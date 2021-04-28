require 'spec_helper'

describe Spree::StoreController, type: :controller do
  describe '#store_etag' do
    let!(:store) { create(:store, default: true, default_locale: 'es', default_currency: 'EUR') }

    before { controller.send(:set_locale) }
    after { I18n.locale = I18n.default_locale }

    context 'guest visitor' do
      it do
        expect(controller.send(:store_etag)).to eq [
          store,
          'EUR',
          :es,
          false
        ]
      end
    end

    context 'with signed in user' do
      let(:user) { stub_model(Spree::LegacyUser) }

      before do
        allow(controller).to receive_messages try_spree_current_user: user
        allow(controller).to receive_messages spree_current_user: user
      end

      context 'regular user' do
        it do
          expect(controller.send(:store_etag)).to eq [
            store,
            'EUR',
            :es,
            true,
            false
          ]
        end
      end

      context 'admin user' do
        before { user.spree_roles << Spree::Role.find_or_create_by(name: :admin) }

        it do
          expect(controller.send(:store_etag)).to eq [
            store,
            'EUR',
            :es,
            true,
            true
          ]
        end
      end
    end
  end
end
