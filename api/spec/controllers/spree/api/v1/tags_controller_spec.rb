require 'spec_helper'

module Spree
  describe Api::V1::TagsController, type: :controller do
    render_views

    let!(:tag) { create(:tag) }
    let(:base_attributes) { Api::ApiHelpers.tag_attributes }

    before do
      stub_authentication!
    end

    context 'as a normal user' do
      context 'with caching enabled' do
        before do
          create(:tag) # tag_2
          ActionController::Base.perform_caching = true
        end

        it 'returns unique tags' do
          api_get :index
          tag_ids = json_response['tags'].map { |p| p['id'] }
          expect(tag_ids.uniq.count).to eq(tag_ids.count)
        end

        after do
          ActionController::Base.perform_caching = false
        end
      end

      it 'retrieves a list of tags' do
        api_get :index
        expect(json_response['tags'].first).to have_attributes(base_attributes)
        expect(json_response['total_count']).to eq(1)
        expect(json_response['current_page']).to eq(1)
        expect(json_response['pages']).to eq(1)
        expect(json_response['per_page']).to eq(Kaminari.config.default_per_page)
      end

      it 'retrieves a list of tags by id' do
        api_get :index, ids: [tag.id]
        expect(json_response['tags'].first).to have_attributes(base_attributes)
        expect(json_response['total_count']).to eq(1)
        expect(json_response['current_page']).to eq(1)
        expect(json_response['pages']).to eq(1)
        expect(json_response['per_page']).to eq(Kaminari.config.default_per_page)
      end

      it 'retrieves a list of tags by ids string' do
        second_tag = create(:tag)
        api_get :index, ids: [tag.id, second_tag.id].join(',')
        expect(json_response['tags'].first).to have_attributes(base_attributes)
        expect(json_response['tags'][1]).to have_attributes(base_attributes)
        expect(json_response['total_count']).to eq(2)
        expect(json_response['current_page']).to eq(1)
        expect(json_response['pages']).to eq(1)
        expect(json_response['per_page']).to eq(Kaminari.config.default_per_page)
      end

      context 'pagination' do
        before { create(:tag) } # second_tag

        it 'can select the next page of tags' do
          api_get :index, page: 2, per_page: 1
          expect(json_response['tags'].first).to have_attributes(base_attributes)
          expect(json_response['total_count']).to eq(2)
          expect(json_response['current_page']).to eq(2)
          expect(json_response['pages']).to eq(2)
        end

        it 'can control the page size through a parameter' do
          api_get :index, per_page: 1
          expect(json_response['count']).to eq(1)
          expect(json_response['total_count']).to eq(2)
          expect(json_response['current_page']).to eq(1)
          expect(json_response['pages']).to eq(2)
        end
      end

      it 'can search for tags' do
        create(:tag, name: 'The best tag in the world')
        api_get :index, q: { name_cont: 'best' }
        expect(json_response['tags'].first).to have_attributes(base_attributes)
        expect(json_response['count']).to eq(1)
      end
    end

    context 'as an admin' do
      sign_in_as_admin!

      it 'can see all tags' do
        api_get :index
        expect(json_response['tags'].count).to eq(1)
        expect(json_response['count']).to eq(1)
        expect(json_response['current_page']).to eq(1)
        expect(json_response['pages']).to eq(1)
      end
    end
  end
end
