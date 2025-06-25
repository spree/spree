require 'spec_helper'

RSpec.describe 'Post details page', :js, type: :feature do
  describe 'JSON-LD data' do
    let(:store) { Spree::Store.default }
    let!(:post) do
      create(
        :post, :with_image,
        post_category: post_category,
        tag_list: tags,
        title: 'New products on sale!',
        author: create(:admin_user, name: 'John Doe'),
        published_at: '2024-10-07T08:10:08-05:00'
      )
    end

    let(:tags) { [] }

    let(:json_ld) { JSON.parse(find('script[data-test-id="post-json-ld"]', visible: false)['innerHTML']) }
    let(:json_ld_breadcrumbs) { JSON.parse(find('script[data-test-id="post-breadcrumbs-json-ld"]', visible: false)['innerHTML']) }

    before do
      visit spree.post_path(post)
    end

    context 'for a post with a category' do
      let(:post_category) { create(:post_category, title: 'Articles') }

      it 'renders BlogPosting JSON-LD' do
        expect(json_ld).to match(
          '@context' => 'https://schema.org',
          '@type' => 'BlogPosting',
          'headline' => 'New products on sale!',
          'image' => array_including(kind_of(String)),
          'datePublished' => post.published_at.iso8601,
          'dateModified' => post.updated_at.iso8601,
          'author' => [
            {
              '@type' => 'Person',
              'name' => 'John Doe'
            }
          ]
        )
      end

      it 'renders BreadcrumbList JSON-LD with a link to category page' do
        expect(json_ld_breadcrumbs).to match(
          {
            '@context' => 'https://schema.org',
            '@type' => 'BreadcrumbList',
            'itemListElement' => [
              {
                '@type' => 'ListItem',
                'position' => 1,
                'name' => Spree.t(:homepage),
                'item' => "#{store.formatted_url}/"
              },
              {
                '@type' => 'ListItem',
                'position' => 2,
                'name' => Spree.t(:blog),
                'item' => [store.formatted_url, 'posts'].join('/')
              },
              {
                '@type' => 'ListItem',
                'position' => 3,
                'name' => 'Articles',
                'item' => [store.formatted_url, 'posts', 'category', post_category.slug].join('/')
              },
              {
                '@type' => 'ListItem',
                'position' => 4,
                'name' => 'New products on sale!'
              }
            ]
          }
        )
      end
    end

    context 'for a post without a category' do
      let(:post_category) { nil }

      it 'renders JSON-LD' do
        expect(json_ld).to match(
          '@context' => 'https://schema.org',
          '@type' => 'BlogPosting',
          'headline' => 'New products on sale!',
          'image' => array_including(kind_of(String)),
          'datePublished' => post.published_at.iso8601,
          'dateModified' => post.updated_at.iso8601,
          'author' => [
            {
              '@type' => 'Person',
              'name' => 'John Doe'
            }
          ]
        )

        expect(json_ld_breadcrumbs).to eq(
          {
            '@context' => 'https://schema.org',
            '@type' => 'BreadcrumbList',
            'itemListElement' => [
              {
                '@type' => 'ListItem',
                'position' => 1,
                'name' => Spree.t(:homepage),
                'item' => "#{store.formatted_url}/"
              },
              {
                '@type' => 'ListItem',
                'position' => 2,
                'name' => Spree.t(:blog),
                'item' => [store.formatted_url, 'posts'].join('/')
              },
              {
                '@type' => 'ListItem',
                'position' => 3,
                'name' => 'New products on sale!'
              }
            ]
          }
        )
      end
    end
  end
end
