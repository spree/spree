require 'spec_helper'

describe Spree::CmsPagesController, type: :controller do
  let!(:store) { create(:store, default: true, default_locale: 'en', default_currency: 'USD') }

  describe '#show - when page is set the current store' do
    let!(:cms_page) { create(:cms_standard_page, store: store, locale: 'en') }

    it 'returns a successful response' do
      get :show, params: { slug: cms_page.slug }
      expect(response).to be_successful
    end
  end

  describe '#show - when page is set the current store but visible false' do
    let!(:cms_page_visible) { create(:cms_standard_page, store: store, locale: 'en', visible: false) }

    it 'returns ActiveRecord::RecordNotFound' do
      expect { get :show, params: { slug: cms_page_visible.slug } }.to raise_error ActiveRecord::RecordNotFound
    end
  end

  describe '#show - when page is set for another store' do
    let!(:store_b) { create(:store, default: false, default_locale: 'de', default_currency: 'EUR') }
    let!(:cms_page_b) { create(:cms_standard_page, store: store_b, locale: 'de') }

    it 'returns ActiveRecord::RecordNotFound' do
      expect { get :show, params: { slug: cms_page_b.slug } }.to raise_error ActiveRecord::RecordNotFound
    end
  end
end
