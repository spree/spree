module Spree
  module PostsHelper
    def posts_json_ld_breadcrumbs(post)
      json_ld = {
        '@context' => 'https://schema.org',
        '@type' => 'BreadcrumbList',
        'itemListElement' => [
          {
            '@type' => 'ListItem',
            'position' => 1,
            'name' => Spree.t(:homepage),
            'item' => spree.root_url(host: current_store.url_or_custom_domain)
          },
          {
            '@type' => 'ListItem',
            'position' => 2,
            'name' => Spree.t(:blog),
            'item' => spree.posts_url(host: current_store.url_or_custom_domain)
          }
        ]
      }

      post_breadcrumb = { '@type' => 'ListItem', 'name' => post.title }
      post_category = post.post_category

      if post_category.present?
        json_ld['itemListElement'] << {
          '@type' => 'ListItem',
          'position' => 3,
          'name' => post_category.title,
          'item' => spree.category_posts_url(category_id: post.post_category.slug, host: current_store.url_or_custom_domain)
        }

        json_ld['itemListElement'] << post_breadcrumb.merge('position' => 4)
      else
        json_ld['itemListElement'] << post_breadcrumb.merge('position' => 3)
      end

      json_ld
    end
  end
end
