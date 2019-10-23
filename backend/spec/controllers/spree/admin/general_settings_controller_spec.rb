require 'spec_helper'

describe Spree::Admin::GeneralSettingsController, type: :controller do
  let(:user) { create(:user) }

  before do
    allow(controller).to receive_messages spree_current_user: user
    user.spree_roles << Spree::Role.find_or_create_by(name: 'admin')
  end

  describe '#clear_cache' do
    subject { post :clear_cache }

    shared_examples 'a HTTP 204 response' do
      it 'grant access to users with an admin role' do
        subject
        expect(response.status).to eq(204)
      end
    end

    context 'when no callback' do
      it_behaves_like 'a HTTP 204 response'
    end

    context 'when callback implemented' do
      Spree::Admin::GeneralSettingsController.class_eval do
        custom_callback(:clear_cache).after :foo

        def foo
          # Make a call to Akamai, CloudFlare, etc invalidation....
        end
      end

      before do
        expect(controller).to receive(:foo).once
      end

      it_behaves_like 'a HTTP 204 response'
    end
  end
end
