require 'spec_helper'

describe 'Platform API v2 Menu Items spec', type: :request do
  include_context 'API v2 tokens'
  include_context 'Platform API v2'

  let!(:store) { create(:store, default: true) }
  let!(:menu) { create(:menu, store: store) }
  let!(:menu_item_a) { create(:menu_item, menu: menu) }
  let!(:menu_item_b) { create(:menu_item, menu: menu) }
  let!(:menu_item_c) { create(:menu_item, menu: menu, parent: menu_item_b) }
  let(:bearer_token) { { 'Authorization' => valid_authorization } }

  describe 'menu_item#reposition' do
    context 'with no params' do
      let(:params) { nil }

      before do
        patch '/api/v2/platform/menu_items/reposition', headers: bearer_token, params: params
      end

      it_behaves_like 'returns 404 HTTP status'
    end

    context 'with correct params' do
      let(:params) { { moved_item_id: menu_item_a.id, new_parent_id: menu_item_b.id, new_position_idx: 0 } }

      before do
        patch '/api/v2/platform/menu_items/reposition', headers: bearer_token, params: params
      end

      it_behaves_like 'returns 204 HTTP status'

      it 'can be nested inside another item' do
        menu_item_a.reload
        expect(menu_item_a.parent_id).to eq(menu_item_b.id)

        # Root depth = 0
        # Menu Item B depth = 1 (created inside menu.root)
        # Menu Item A depth = 2 (now moved inside Menu Item B)
        expect(menu_item_a.depth).to eq(2)
      end
    end

    context 'with correct params moving within same item' do
      let(:params) { { moved_item_id: menu_item_a.id, new_parent_id: menu_item_b.id, new_position_idx: 1 } }

      before do
        patch "/api/v2/platform/menu_items/reposition", headers: bearer_token, params: params
      end

      it_behaves_like 'returns 204 HTTP status'

      it 're-indexes the item' do
        menu_item_a.reload
        expect(menu_item_a.parent_id).to eq(menu_item_b.id)
        expect(menu_item_a.lft).to eq(menu_item_c.lft)
      end
    end
  end
end
