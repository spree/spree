require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CategoriesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  # A top-level category — parentless, store-owned, no taxonomy.
  let!(:category) { Spree::Category.create!(name: 'Clothing', store: store) }
  # A legacy taxonomy is still needed to host automatic (collection) taxons,
  # which the category API must exclude.
  let(:taxonomy) { create(:taxonomy, store: store) }

  before { request.headers.merge!(headers) }

  def created_category
    Spree::Category.find_by_prefix_id(json_response['id'])
  end

  describe 'GET #index' do
    let!(:automatic) { create(:automatic_taxon, name: 'On Sale', taxonomy: taxonomy, parent: taxonomy.root) }

    it 'lists manual categories and excludes automatic (collection) taxons' do
      get :index, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      ids = json_response['data'].map { |c| c['id'] }
      expect(ids).to include(category.prefixed_id)
      expect(ids).not_to include(automatic.prefixed_id)
    end
  end

  describe 'GET #show' do
    it 'returns the category' do
      get :show, params: { id: category.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Clothing')
    end

    it 'exposes the product count' do
      create_list(:product, 2).each { |p| p.taxons << category }
      get :show, params: { id: category.prefixed_id }, as: :json

      expect(json_response['products_count']).to eq(2)
    end

    it 'rolls subcategory products up into the product count' do
      child = Spree::Category.create!(name: 'Shirts', parent: category)
      create(:product).taxons << category
      create(:product).taxons << child

      get :show, params: { id: category.prefixed_id }, as: :json

      expect(json_response['products_count']).to eq(2) # 1 direct + 1 from child
    end

    it 'does not expose an automatic (collection) taxon as a category' do
      automatic = create(:automatic_taxon, taxonomy: taxonomy, parent: taxonomy.root)
      get :show, params: { id: automatic.prefixed_id }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'creates a category nested under the given parent' do
      post :create, params: { name: 'Shirts', parent_id: category.prefixed_id }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('Shirts')
      expect(created_category.parent_id).to eq(category.id)
    end

    it 'creates a top-level category (no parent, owned by the store) when no parent is given' do
      post :create, params: { name: 'Footwear' }, as: :json

      expect(response).to have_http_status(:created)
      created = created_category
      expect(created.parent).to be_nil
      expect(created.store).to eq(store)
      expect(created.taxonomy).to be_nil
    end

    it 'returns 422 for a blank name' do
      post :create, params: { name: '', parent_id: category.prefixed_id }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'ignores collection-bound params (automatic stays false)' do
      post :create, params: { name: 'Sale-ish', parent_id: category.prefixed_id, automatic: true, sort_order: 'best_selling' }, as: :json

      expect(response).to have_http_status(:created)
      expect(created_category.automatic).to be(false)
    end
  end

  describe 'PATCH #update' do
    it 'updates category attributes' do
      patch :update, params: { id: category.prefixed_id, name: 'Apparel' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(category.reload.name).to eq('Apparel')
    end

    it 'cannot target an automatic (collection) taxon' do
      automatic = create(:automatic_taxon, taxonomy: taxonomy, parent: taxonomy.root)
      patch :update, params: { id: automatic.prefixed_id, name: 'Hijacked' }, as: :json
      expect(response).to have_http_status(:not_found)
    end

    it 'purges the image when image is set to null' do
      # Attach reliably persists on a factory-built taxon; the controller treats
      # it the same as a store-owned Category (both resolve through `scope`).
      imaged = create(:taxon, :with_header_image, taxonomy: taxonomy, parent: taxonomy.root)
      expect(imaged.reload.image).to be_attached

      patch :update, params: { id: imaged.prefixed_id, image: nil }, as: :json

      expect(response).to have_http_status(:ok)
      expect(imaged.reload.image).not_to be_attached
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the category' do
      delete :destroy, params: { id: category.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::Category.find_by_prefix_id(category.prefixed_id)).to be_nil
    end

    it 'cannot delete an automatic (collection) taxon' do
      automatic = create(:automatic_taxon, taxonomy: taxonomy, parent: taxonomy.root)
      delete :destroy, params: { id: automatic.prefixed_id }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH #reposition' do
    # Top-level categories (parentless, store-owned) created in order.
    let!(:first)  { Spree::Category.create!(name: 'A First', store: store) }
    let!(:second) { Spree::Category.create!(name: 'B Second', store: store) }
    let!(:third)  { Spree::Category.create!(name: 'C Third', store: store) }

    # Helper: ordered ids of a parent's children (nested-set order).
    def child_ids(parent)
      parent.children.reload.order(:lft).pluck(:id)
    end

    context 'changing the parent' do
      it 'moves a category under a new parent at the given index' do
        patch :reposition, params: { id: third.prefixed_id, new_parent_id: first.prefixed_id, new_position: 0 }, as: :json

        expect(response).to have_http_status(:ok)
        expect(third.reload.parent_id).to eq(first.id)
        expect(child_ids(first)).to eq([third.id])
      end

      it 'inserts among existing children at the requested index' do
        existing = Spree::Category.create!(name: 'Existing', parent: first)

        patch :reposition, params: { id: third.prefixed_id, new_parent_id: first.prefixed_id, new_position: 0 }, as: :json

        expect(response).to have_http_status(:ok)
        expect(child_ids(first)).to eq([third.id, existing.id])
      end

      it 'reorders among an existing parent\'s children' do
        a = Spree::Category.create!(name: 'A', parent: first)
        b = Spree::Category.create!(name: 'B', parent: first)

        patch :reposition, params: { id: b.prefixed_id, new_parent_id: first.prefixed_id, new_position: 0 }, as: :json

        expect(response).to have_http_status(:ok)
        expect(child_ids(first)).to eq([b.id, a.id])
      end

      it 'clamps an out-of-range index instead of 404ing' do
        # Regression: new_position past the child count dereferenced a nil
        # sibling and returned 404. With second already a child, moving third in
        # at an out-of-range index must succeed (append) rather than 404.
        Spree::Category.create!(name: 'Existing child', parent: first)

        patch :reposition, params: { id: third.prefixed_id, new_parent_id: first.prefixed_id, new_position: 999 }, as: :json

        expect(response).to have_http_status(:ok)
        expect(third.reload.parent_id).to eq(first.id)
      end

      it 'promotes a nested category to the top level when no parent is given' do
        nested = Spree::Category.create!(name: 'Nested', parent: first)

        patch :reposition, params: { id: nested.prefixed_id, new_position: 0 }, as: :json

        expect(response).to have_http_status(:ok)
        expect(nested.reload.parent).to be_nil
      end

      it 'returns 422 for an impossible move (into its own descendant)' do
        child = Spree::Category.create!(name: 'Child', parent: first)

        patch :reposition, params: { id: first.prefixed_id, new_parent_id: child.prefixed_id, new_position: 0 }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'cannot reposition an automatic (collection) taxon' do
        automatic = create(:automatic_taxon, taxonomy: taxonomy, parent: taxonomy.root)

        patch :reposition, params: { id: automatic.prefixed_id, new_position: 0 }, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'reordering top-level categories (no parent change)' do
      # The fixture root `category` ('Clothing') is the 0th sibling; first/
      # second/third follow it. Assert on the ordering of OUR three roots only.
      def ordered_trio
        ids = [first.id, second.id, third.id]
        Spree::Category.where(parent_id: nil).order(:lft).pluck(:id).select { |id| ids.include?(id) }
      end

      it 'moves a root category to the first position among its siblings' do
        # new_position 1 = just after the fixture root, i.e. first of our trio.
        patch :reposition, params: { id: third.prefixed_id, new_position: 1 }, as: :json

        expect(response).to have_http_status(:ok)
        expect(third.reload.parent_id).to be_nil
        expect(ordered_trio).to eq([third.id, first.id, second.id])
      end

      it 'moves a root category to the last position' do
        patch :reposition, params: { id: first.prefixed_id, new_position: 3 }, as: :json

        expect(response).to have_http_status(:ok)
        expect(ordered_trio).to eq([second.id, third.id, first.id])
      end

      it 'moves a root category to a middle position' do
        patch :reposition, params: { id: first.prefixed_id, new_position: 2 }, as: :json

        expect(response).to have_http_status(:ok)
        expect(ordered_trio).to eq([second.id, first.id, third.id])
      end

      it 'clamps an out-of-range top-level index to the end' do
        patch :reposition, params: { id: first.prefixed_id, new_position: 999 }, as: :json

        expect(response).to have_http_status(:ok)
        expect(ordered_trio.last).to eq(first.id)
      end
    end

    context 'invalid new_position' do
      it 'returns 422 for a missing new_position' do
        patch :reposition, params: { id: first.prefixed_id }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns 422 for a non-integer new_position' do
        patch :reposition, params: { id: first.prefixed_id, new_position: 'abc' }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
