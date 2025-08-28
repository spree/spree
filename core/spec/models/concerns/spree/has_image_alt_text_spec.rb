require 'spec_helper'

RSpec.describe Spree::HasImageAltText, type: :concern do
  # Create a dummy class to test the concern
  let(:dummy_class) do
    Class.new do
      include Spree::HasImageAltText

      attr_accessor :preferred_image_alt, :asset
      
      def initialize
        @preferred_image_alt = nil
        @asset = nil
      end
    end
  end

  let(:instance) { dummy_class.new }

  describe 'included behavior' do
    it 'creates the image_alt method' do
      expect(instance).to respond_to(:image_alt)
    end

    it 'returns preference value when present' do
      instance.preferred_image_alt = 'Custom alt text'
      expect(instance.image_alt).to eq('Custom alt text')
    end

    it 'returns filename-based alt when preference is blank but asset has filename' do
      instance.preferred_image_alt = ''

      # Mock asset with filename
      asset_double = double('asset')
      allow(asset_double).to receive(:filename).and_return('test-image_file.jpg')
      instance.asset = asset_double

      expect(instance.image_alt).to eq('test image file')
    end

    it 'returns "Image" as fallback when no preference and no asset' do
      instance.preferred_image_alt = nil
      instance.asset = nil

      expect(instance.image_alt).to eq('Image')
    end

    context 'when asset has no filename' do
      it 'returns "Image" fallback' do
        instance.preferred_image_alt = nil

        # Mock asset without filename
        asset_double = double('asset')
        allow(asset_double).to receive(:filename).and_return(nil)
        instance.asset = asset_double

        expect(instance.image_alt).to eq('Image')
      end
    end

    context 'filename processing' do
      it 'correctly converts various filename formats' do
        instance.preferred_image_alt = nil

        test_cases = [
          ['hero-banner_image.jpg', 'hero banner image'],
          ['product_photo-main.png', 'product photo main'],
          ['logo.svg', 'logo'],
          ['My-File_Name.webp', 'My File Name']
        ]

        test_cases.each do |filename, expected_alt|
          asset_double = double('asset')
          allow(asset_double).to receive(:filename).and_return(filename)
          instance.asset = asset_double

          expect(instance.image_alt).to eq(expected_alt)
        end
      end
    end
  end
end
