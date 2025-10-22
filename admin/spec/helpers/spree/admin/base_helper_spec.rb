require 'spec_helper'

describe Spree::Admin::BaseHelper do
  describe '#render_avatar' do
    let(:user) { create(:admin_user) }

    context 'when user has an avatar' do
      before { user.avatar.attach(io: File.new(Spree::Core::Engine.root + 'spec/fixtures/thinking-cat.jpg'), filename: 'thinking-cat.jpg') }

      it 'returns the avatar url' do
        ActiveStorage::Current.url_options = { host: 'localhost', port: 3000 }
        expect(render_avatar(user)).to match(/rails\/active_storage/)
        expect(render_avatar(user)).to match(/thinking-cat\.jpg/)
      end
    end

    context 'when user does not have an avatar' do
      it 'returns initials' do
        expect(render_avatar(user)).to match(/avatar/)
      end
    end
  end

  describe '#spree_time_ago' do
    it 'returns the local time ago with a tooltip' do
      time = Time.zone.parse('2025-10-21 12:00')
      html = helper.spree_time_ago(time)
      expect(html).to include('<time datetime="2025-10-21T12:00')
      expect(html).to include('tooltip-container')
    end

    it 'returns empty string for blank time' do
      expect(helper.spree_time_ago(nil)).to eq('')
    end
  end
end
