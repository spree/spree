require 'spec_helper'

describe Spree::Admin::CmsHelper, type: :helper do
  include Spree::BaseHelper

    let!(:current_store) { create(:store) }
    let!(:standard_page) { create(:cms_standard_page) }
    let!(:feature_page) { create(:cms_feature_page) }
    let!(:home_page) { create(:cms_homepage) }

  describe '#cms_page_preview_url' do
    before do
      @standard_page = Spree::CmsPage.find(standard_page.id)
      @feature_page = Spree::CmsPage.find(feature_page.id)
      @home_page = Spree::CmsPage.find(home_page.id)
    end

    context 'standard_page' do
      it "returns the correct URL when page language matches the current store default language" do
        expect(cms_page_preview_url(@standard_page)).to eq("http://www.example.com/pages/#{@standard_page.slug}")
      end

      it "returns the language denomination in the URL when page language does not match the current store default language" do
        @standard_page.update!(locale: :fr)
        @standard_page.reload

        expect(cms_page_preview_url(@standard_page)).to eq("http://www.example.com/fr/pages/#{@standard_page.slug}")

        @standard_page.update!(locale: :en)
        @standard_page.reload
      end
    end

    context 'feature_page' do
      it "returns the correct URL when page language matches the current store default language" do
        expect(cms_page_preview_url(@feature_page)).to eq("http://www.example.com/pages/#{@feature_page.slug}")
      end

      it "returns the language denomination in the URL when page language does not match the current store default language" do
        @feature_page.update!(locale: :fr)
        @feature_page.reload

        expect(cms_page_preview_url(@feature_page)).to eq("http://www.example.com/fr/pages/#{@feature_page.slug}")

        @feature_page.update!(locale: :en)
        @feature_page.reload
      end
    end

    context 'home_page' do
      it "returns the correct URL when page language matches the current store default language" do
        expect(cms_page_preview_url(@home_page)).to eq("http://www.example.com")
      end

      it "returns the language denomination in the URL when page language does not match the current store default language" do
        @home_page.update!(locale: :fr)
        @home_page.reload

        expect(cms_page_preview_url(@home_page)).to eq("http://www.example.com/fr")

        @home_page.update!(locale: :en)
        @home_page.reload
      end
    end
  end
end
