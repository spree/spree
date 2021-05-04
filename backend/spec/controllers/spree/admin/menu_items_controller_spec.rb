require 'spec_helper'

describe Spree::Admin::MenusController, type: :controller do
  stub_authorization!

  let!(:store) { create(:store) }
  let!(:menu) { create(:menu, unique_code: 'xyz', store_id: store.id) }
  let(:image_file) { Rack::Test::UploadedFile.new(Spree::Backend::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')) }
  let(:menu_item) { create(:menu_item, menu_id: menu.id, parent_id: menu.root.id, image_asset: image_file) }

  describe 'GET index' do
    it 'is ok' do
      get :index
      expect(response).to be_ok
    end
  end
end
