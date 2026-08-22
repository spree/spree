require 'spec_helper'

RSpec.describe Spree::Api::V3::MediaSerializer do
  let(:store) { @default_store }
  let(:product) { create(:product, store: store) }

  # A DAM keeps the master image and its renditions; Spree stores the address,
  # not the bytes, so nothing here goes through ActiveStorage.
  describe 'an image hosted elsewhere' do
    let(:media) do
      Spree::Media.create!(viewable: product, media_type: 'external_image',
                           external_media_url: 'https://cdn.example.com/widget.jpg')
    end

    let(:json) { JSON.parse(described_class.new(media).to_json) }

    it 'serves the hosted address as the image' do
      expect(json['original_url']).to eq('https://cdn.example.com/widget.jpg')
    end

    it 'answers every requested size with the address the DAM serves' do
      expect(json['small_url']).to eq('https://cdn.example.com/widget.jpg')
      expect(json['large_url']).to eq('https://cdn.example.com/widget.jpg')
    end

    it 'reports the address' do
      expect(json['external_media_url']).to eq('https://cdn.example.com/widget.jpg')
      expect(json['external_video_url']).to be_nil
    end
  end

  describe 'an image Spree stores itself' do
    let(:media) { create(:image, viewable: product) }

    it 'is unaffected and still builds its own variants' do
      json = JSON.parse(described_class.new(media).to_json)

      expect(json['original_url']).to be_present
      expect(json['external_media_url']).to be_nil
    end
  end
end
