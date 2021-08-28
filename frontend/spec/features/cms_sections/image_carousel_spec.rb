require 'spec_helper'

describe 'Visiting the homepage with image carousel', type: :feature, js: true do
  let!(:store) { Spree::Store.default }

  let!(:homepage) { create(:cms_homepage, store: store, locale: 'en') }
  let!(:carousel_section) { create(:cms_image_carousel_section, cms_page: homepage) }

  let(:image_file_one) { File.open("#{Spree::Core::Engine.root}/spec/fixtures/thinking-cat.jpg") }
  let(:image_file_three) { File.open("#{Spree::Core::Engine.root}/spec/fixtures/thinking-cat.jpg") }
  let(:iamge_one) { Rack::Test::UploadedFile.new("#{Spree::Core::Engine.root}/spec/fixtures/thinking-cat.jpg") }
  let(:main_app) { Rails.application.routes.url_helpers }

  context 'when page is viewed and carousel has all options activated' do
    before do
      section = Spree::CmsSection.find(carousel_section.id)
      section.image_one.attach(io: image_file_one, filename: 'thinking-cat1.jpg', content_type: 'image/jpeg')
      section.image_three.attach(io: image_file_three, filename: 'thinking-cat3.jpg', content_type: 'image/jpeg')
      section.title_one = 'Title one'
      section.title_three = 'Title three'
      section.link_type_three = 'Spree::Taxon'
      section.link_three = 'categories/men/shirts'
      section.captions = '1'
      section.controls = '1'
      section.indicators = '1'
      section.autoplay = '1'
      section.pause = '1'
      section.wrap = '1'
      section.save

      visit spree.root_path
    end

    it 'the carousel section displays the images with links' do
      expect(page).to have_selector(:css, 'img[alt="Title one"][data-src*="thinking-cat1.jpg"]')
      expect(page).to have_selector(:css, 'img[alt="Title three"][data-src*="thinking-cat3.jpg"]')
    end

    it 'the carousel section displays the links' do
      expect(page).not_to have_selector(:css, 'a img[alt="Title one"]')
      expect(page).to have_selector(:css, 'a[href="/t/categories/men/shirts"] img[alt="Title three"]')
    end

    it 'has cations' do
      expect(page).to have_selector(:css, '.carousel-caption', text: 'Title one')
      expect(page).to have_selector(:css, '.carousel-caption', text: 'Title three')
    end

    it 'has controls' do
      expect(page).to have_selector(:css, '.carousel-control-next')
      expect(page).to have_selector(:css, '.carousel-control-prev')
    end

    it 'has indicators' do
      expect(page).to have_selector(:css, '.carousel-indicators')
    end

    it 'has autoplay' do
      expect(page).to have_selector(:css, '.carousel[data-ride="carousel"]')
    end

    it 'has pause' do
      expect(page).not_to have_selector(:css, '.carousel[data-pause="false"]')
    end

    it 'has wrap' do
      expect(page).not_to have_selector(:css, '.carousel[data-wrap="false"]')
    end
  end

  context 'when page is viewed and carousel has all options deactivated' do
    before do
      section = Spree::CmsSection.find(carousel_section.id)
      section.image_one.attach(io: image_file_one, filename: 'thinking-cat1.jpg', content_type: 'image/jpeg')
      section.title_one = 'Title one'
      section.captions = '0'
      section.controls = '0'
      section.indicators = '0'
      section.autoplay = '0'
      section.pause = '0'
      section.wrap = '0'
      section.save

      visit spree.root_path
    end

    it 'the carousel section displays the images' do
      expect(page).to have_selector(:css, 'img[alt="Title one"][data-src*="thinking-cat1.jpg"]')
    end

    it 'does not have cations' do
      expect(page).not_to have_selector(:css, '.carousel-caption', text: 'Title one')
      expect(page).not_to have_selector(:css, '.carousel-caption', text: 'Title three')
    end

    it 'does not have controls' do
      expect(page).not_to have_selector(:css, '.carousel-control-next')
      expect(page).not_to have_selector(:css, '.carousel-control-prev')
    end

    it 'does not have indicators' do
      expect(page).not_to have_selector(:css, '.carousel-indicators')
    end

    it 'does not have autoplay' do
      expect(page).not_to have_selector(:css, '.carousel[data-ride="carousel"]')
    end

    it 'does not have pause' do
      expect(page).to have_selector(:css, '.carousel[data-pause="false"]')
    end

    it 'does not have wrap' do
      expect(page).to have_selector(:css, '.carousel[data-wrap="false"]')
    end
  end
end
