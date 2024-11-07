require 'spec_helper'

describe Spree::Admin::BaseHelper do
  describe '#avatar_url_for' do
    let(:user) { create(:admin_user) }

    context 'when user has an avatar' do
      before { user.avatar.attach(io: File.new(Spree::Core::Engine.root + 'spec/fixtures/thinking-cat.jpg'), filename: 'thinking-cat.jpg') }

      it 'returns the avatar url' do
        ActiveStorage::Current.url_options = { host: 'localhost', port: 3000 }
        expect(avatar_url_for(user)).to match(/rails\/active_storage/)
        expect(avatar_url_for(user)).to match(/thinking-cat\.jpg/)
      end
    end

    context 'when user does not have an avatar' do
      it 'returns initials' do
        expect(avatar_url_for(user)).to match(/eu\.ui-avatars\.com/)
      end
    end
  end
end
