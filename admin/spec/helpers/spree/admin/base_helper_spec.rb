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

  describe '#external_page_preview_link' do
    let(:current_store) { create(:store) }
    let(:product) { create(:product, stores: [current_store]) }

    def spree_storefront_resource_url(*_args); end
    def button_link_to(*_args); end
    def link_to_with_icon(*_args); end

    context 'for product' do
      context 'when product is a draft' do
        before { product.update(status: :draft) }

        it 'should call spree_storefront_resource_url with preview_id' do
          expect(self).to receive(:spree_storefront_resource_url).with(product, preview_id: product.id)

          external_page_preview_link(product)
        end
      end

      context 'when product is not a draft' do
        it 'should call spree_storefront_resource_url with preview_id' do
          expect(self).to receive(:spree_storefront_resource_url).with(product, preview_id: product.id)

          external_page_preview_link(product)
        end
      end
    end
  end
end
