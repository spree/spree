require 'spec_helper'

class PageBuilderUrlClass
  include Spree::PageBuilderUrl
  page_builder_route_with :products_path

  attr_reader :store

  def initialize(store)
    @store = store
  end
end

class PageBuilderUrlClassWithRouteParams
  include Spree::PageBuilderUrl
  page_builder_route_with :page_path, ->(obj) { { id: obj.id } }

  def id
    123
  end
end

class PageBuilderUrlClassWithInvalidRoute
  include Spree::PageBuilderUrl
  page_builder_route_with :invalid_route
end

class PageBuilderUrlHelpers
  def products_path(_params, locale:)
    case locale.to_s
    when 'pl' then '/pl/products'
    when 'en' then '/en/products'
    else '/products'
    end
  end

  def page_path(params, locale:)
    case locale.to_s
    when 'pl' then "/pl/pages/#{params[:id]}"
    when 'en' then "/en/pages/#{params[:id]}"
    else "/pages/#{params[:id]}"
    end
  end
end

RSpec.describe Spree::PageBuilderUrl do
  subject { page_builder_url_object.page_builder_url }

  let(:url_helpers) { PageBuilderUrlHelpers.new }

  before do
    allow(Spree::Core::Engine.routes).to receive(:url_helpers).and_return(url_helpers)
    Spree::Store.default.update!(supported_locales: 'en,pl')
    I18n.locale = current_locale
  end

  after do
    I18n.locale = :en
    Spree::Store.default.update!(supported_locales: 'en')
  end

  context 'for a simple route' do
    let(:page_builder_url_object) { PageBuilderUrlClass.new(store) }
    let(:store) { create(:store, default_locale: 'pl', supported_locales: 'pl,en') }

    context 'when current locale is en' do
      let(:current_locale) { 'en' }

      it { is_expected.to eq('/en/products') }
    end

    context 'when current locale is pl' do
      let(:current_locale) { 'pl' }

      it { is_expected.to eq('/products') }
    end
  end

  context 'for a route with params' do
    let(:page_builder_url_object) { PageBuilderUrlClassWithRouteParams.new }

    context 'when current locale is en' do
      let(:current_locale) { 'en' }

      it { is_expected.to eq('/pages/123') }
    end

    context 'when current locale is pl' do
      let(:current_locale) { 'pl' }

      it { is_expected.to eq('/pl/pages/123') }
    end
  end

  context 'for an invalid route' do
    let(:page_builder_url_object) { PageBuilderUrlClassWithInvalidRoute.new }
    let(:current_locale) { 'pl' }

    it { is_expected.to be(nil) }
  end

  context "when a store doesn't support many locales" do
    let(:page_builder_url_object) { PageBuilderUrlClass.new(store) }
    let(:store) { create(:store, default_locale: 'pl', supported_locales: 'pl') }

    context 'when current locale is en' do
      let(:current_locale) { 'en' }

      it { is_expected.to eq('/products') }
    end

    context 'when current locale is pl' do
      let(:current_locale) { 'pl' }

      it { is_expected.to eq('/products') }
    end
  end
end
