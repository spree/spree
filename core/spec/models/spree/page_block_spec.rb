require 'spec_helper'

RSpec.describe Spree::PageBlock, type: :model do
  let(:page_block) { create(:page_block, :nav) }

  describe 'validations' do
    describe 'asset' do
      it 'validates content type' do
        page_block.asset.attach(
          io: File.open(Spree::Core::Engine.root.join('spec/fixtures/files/icon_256x256.png')), filename: 'icon_256x256.png',
          content_type: 'image/png'
        )
        expect(page_block).to be_valid

        page_block.asset.attach(
          io: File.open(Spree::Core::Engine.root.join('spec/fixtures/files/example.json')), filename: 'example.json',
          content_type: 'application/json'
        )
        expect(page_block).not_to be_valid
      end
    end
  end
end
