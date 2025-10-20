require 'spec_helper'

RSpec.describe Spree::Admin::ImportRowsController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { Spree::Store.default }
  let(:import) { create(:product_import, owner: store) }
  let(:import_row) { create(:import_row, import: import) }

  describe 'GET #show' do
    it 'renders the show template' do
      get :show, params: { import_id: import.number, id: import_row.id }
      expect(response).to render_template(:show)
      expect(assigns(:import)).to eq(import)
      expect(assigns(:import_row)).to eq(import_row)
    end
  end
end
