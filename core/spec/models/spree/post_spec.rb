require 'spec_helper'

RSpec.describe Spree::Post, type: :model do
  let(:post) { create(:post) }

  context 'Validations' do
    describe 'image' do
      it 'validates content type' do
        post.image.attach(
          io: File.open(Spree::Core::Engine.root.join('spec/fixtures/files/icon_256x256.png')), filename: 'icon_256x256.png',
          content_type: 'image/png'
        )
        expect(post).to be_valid

        post.image.attach(
          io: File.open(Spree::Core::Engine.root.join('spec/fixtures/files/example.json')), filename: 'example.json',
          content_type: 'application/json'
        )
        expect(post).not_to be_valid
      end
    end

    describe 'slug' do
      it 'validates uniqueness' do
        other_post = create(:post, slug: 'test-slug')

        post.slug = other_post.slug
        expect(post).not_to be_valid
        expect(post.errors.full_messages).to include('Slug has already been taken')

        other_post.destroy
        expect(post).to be_valid
      end
    end
  end

  describe '#author_name' do
    it 'returns the author name' do
      expect(post.author_name).to eq(post.author.name)
    end

    context 'when author is deleted' do
      let!(:other_admin_user) { create(:admin_user) }

      it 'returns the author name' do
        post.author.destroy!
        post.reload
        expect(post.author_name).to be_nil
      end
    end
  end
end
