require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CategoriesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  # A top-level category — parentless, store-owned, no taxonomy.
  let!(:category) { create(:category, name: 'Clothing', store: store) }

  before { request.headers.merge!(headers) }

  def created_category
    Spree::Category.find_by_prefix_id(json_response['id'])
  end

  describe 'GET #index' do
    it 'lists the store categories' do
      get :index, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |c| c['id'] }).to include(category.prefixed_id)
    end
  end

  describe 'GET #show' do
    it 'returns the category' do
      get :show, params: { id: category.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Clothing')
    end

    it 'exposes the product count' do
      create_list(:product, 2).each { |p| p.categories << category }
      get :show, params: { id: category.prefixed_id }, as: :json

      expect(json_response['products_count']).to eq(2)
    end

    it 'rolls subcategory products up into the product count' do
      child = create(:category, name: 'Shirts', parent: category)
      create(:product).taxons << category
      create(:product).taxons << child

      get :show, params: { id: category.prefixed_id }, as: :json

      expect(json_response['products_count']).to eq(2) # 1 direct + 1 from child
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
  end

  describe 'PATCH #update' do
    it 'updates category attributes' do
      patch :update, params: { id: category.prefixed_id, name: 'Apparel' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(category.reload.name).to eq('Apparel')
    end

    it 'writes rich text through description_html and reads back both shapes' do
      patch :update, params: { id: category.prefixed_id, description_html: '<p>Soft <strong>cotton</strong></p>' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['description_html']).to eq('<p>Soft <strong>cotton</strong></p>')
      expect(json_response['description']).to eq('Soft cotton')
    end

    # The plain field is read-only, and Rails drops unpermitted params rather
    # than rejecting them — so this succeeds while storing nothing.
    it 'ignores a write to the plain description param' do
      category.update!(description: '<p>original</p>')

      patch :update, params: { id: category.prefixed_id, description: '<p>attempted</p>' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(category.reload.description).to eq('<p>original</p>')
    end

    it 'purges the image when image is set to null' do
      # Attach reliably persists on a factory-built category; the controller treats
      # it the same as a store-owned Category (both resolve through `scope`).
      imaged = create(:category, :with_header_image)
      expect(imaged.reload.image).to be_attached

      patch :update, params: { id: imaged.prefixed_id, image: nil }, as: :json

      expect(response).to have_http_status(:ok)
      expect(imaged.reload.image).not_to be_attached
    end

    # Category custom-field definitions are stored under Spree::Category (the
    # category route maps to the Taxon class). The dashboard ships values inline
    # with the category form, persisted via Spree::HasCustomFields#custom_fields=.
    context 'with inline custom fields' do
      let!(:fabric_definition) do
        create(:custom_field_definition,
               resource_type: 'Spree::Category',
               namespace: 'category',
               key: 'fabric',
               field_type: 'Spree::CustomFields::ShortText')
      end
      let!(:specs_definition) do
        create(:custom_field_definition,
               resource_type: 'Spree::Category',
               namespace: 'category',
               key: 'specs',
               field_type: 'Spree::CustomFields::Json')
      end

      it 'round-trips an array-shaped JSON custom field value' do
        patch :update, params: {
          id: category.prefixed_id,
          custom_fields: [
            { custom_field_definition_id: specs_definition.prefixed_id, value: %w[a b c] }
          ]
        }, as: :json

        expect(response).to have_http_status(:ok)
        stored = category.reload.custom_fields.find_by(custom_field_definition: specs_definition)
        expect(stored.serialize_value).to eq(%w[a b c])
      end

      it 'round-trips an object-shaped JSON custom field value' do
        patch :update, params: {
          id: category.prefixed_id,
          custom_fields: [
            { custom_field_definition_id: specs_definition.prefixed_id, value: { 'color' => 'red' } }
          ]
        }, as: :json

        expect(response).to have_http_status(:ok)
        stored = category.reload.custom_fields.find_by(custom_field_definition: specs_definition)
        expect(stored.serialize_value).to eq('color' => 'red')
      end

      it 'persists custom_fields inline on update' do
        expect {
          patch :update, params: {
            id: category.prefixed_id,
            custom_fields: [
              { custom_field_definition_id: fabric_definition.prefixed_id, value: 'Linen' }
            ]
          }, as: :json
        }.to change(Spree::CustomField, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(category.reload.custom_fields.find_by(custom_field_definition: fabric_definition).value).to eq('Linen')
      end

      it 'leaves existing values untouched when custom_fields is omitted' do
        category.custom_fields.create!(custom_field_definition: fabric_definition, value: 'Wool')

        patch :update, params: { id: category.prefixed_id, name: 'Apparel' }, as: :json

        expect(response).to have_http_status(:ok)
        expect(category.reload.custom_fields.find_by(custom_field_definition: fabric_definition).value).to eq('Wool')
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the category' do
      delete :destroy, params: { id: category.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::Category.find_by_prefix_id(category.prefixed_id)).to be_nil
    end
  end

  describe 'PATCH #reposition' do
    # Top-level categories (parentless, store-owned) created in order.
    let!(:first)  { create(:category, name: 'A First', store: store) }
    let!(:second) { create(:category, name: 'B Second', store: store) }
    let!(:third)  { create(:category, name: 'C Third', store: store) }

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
        existing = create(:category, name: 'Existing', parent: first)

        patch :reposition, params: { id: third.prefixed_id, new_parent_id: first.prefixed_id, new_position: 0 }, as: :json

        expect(response).to have_http_status(:ok)
        expect(child_ids(first)).to eq([third.id, existing.id])
      end

      it 'reorders among an existing parent\'s children' do
        a = create(:category, name: 'A', parent: first)
        b = create(:category, name: 'B', parent: first)

        patch :reposition, params: { id: b.prefixed_id, new_parent_id: first.prefixed_id, new_position: 0 }, as: :json

        expect(response).to have_http_status(:ok)
        expect(child_ids(first)).to eq([b.id, a.id])
      end

      it 'clamps an out-of-range index instead of 404ing' do
        # Regression: new_position past the child count dereferenced a nil
        # sibling and returned 404. With second already a child, moving third in
        # at an out-of-range index must succeed (append) rather than 404.
        create(:category, name: 'Existing child', parent: first)

        patch :reposition, params: { id: third.prefixed_id, new_parent_id: first.prefixed_id, new_position: 999 }, as: :json

        expect(response).to have_http_status(:ok)
        expect(third.reload.parent_id).to eq(first.id)
      end

      it 'promotes a nested category to the top level when no parent is given' do
        nested = create(:category, name: 'Nested', parent: first)

        patch :reposition, params: { id: nested.prefixed_id, new_position: 0 }, as: :json

        expect(response).to have_http_status(:ok)
        expect(nested.reload.parent).to be_nil
      end

      it 'returns 422 for an impossible move (into its own descendant)' do
        child = create(:category, name: 'Child', parent: first)

        patch :reposition, params: { id: first.prefixed_id, new_parent_id: child.prefixed_id, new_position: 0 }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
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
