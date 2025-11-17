require 'spec_helper'

RSpec.describe Spree::PostCategory, type: :model do
  let(:post_category) { build(:post_category) }

  context 'Associations' do
    describe 'posts' do
      it 'has many posts' do
        post1 = create(:post, post_category: post_category)
        post2 = create(:post, post_category: post_category)

        expect(post_category.posts).to include(post1, post2)
      end

      it 'nullifies posts when destroyed' do
        post = create(:post, post_category: post_category)

        post_category.destroy
        post.reload

        expect(post.post_category).to be_nil
      end
    end
  end

  describe 'FriendlyId' do
    before do
      post_category.save!
    end

    describe '#should_generate_new_friendly_id?' do
      it 'returns true when slug is blank' do
        post_category.slug = nil
        expect(post_category.should_generate_new_friendly_id?).to be true
      end

      it 'returns true when title has changed' do
        post_category.title = 'New Title'
        expect(post_category.should_generate_new_friendly_id?).to be true
      end

      it 'returns false when slug is present and title unchanged' do
        expect(post_category.should_generate_new_friendly_id?).to be false
      end
    end

    describe '#slug_candidates' do
      it 'returns correct slug candidates' do
        expected_candidates = [
          :title,
          [:title, :id]
        ]
        expect(post_category.slug_candidates).to eq(expected_candidates)
      end
    end
  end
end
