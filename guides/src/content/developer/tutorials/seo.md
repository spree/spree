---
title: 'Improve SEO'
section: advanced
order: 0
---

## Overview

Search Engine Optimization is an important area to address when
implementing and developing an ecommerce solution to ensure competitive
search engine performance.

## Headless (API) mode

This guide mostly covers using the default Spree frontend based on Ruby on Rails.
If you're using your own storefront and communicating with Spree over the API
the most important thing will be to properly render `meta_title`, `meta_keywords` and
`meta_description` returned from the Products and Taxons API endpoints.

## Existing Search Engine Optimization Features

Chapter 1 contains a description of the work that has been completed to
address common search engine optimization issues.

### Relevant, Meaningful URLs

The helper method `seo_url(taxon)` yields SEO friendly URLs such as:

 -  `yourstore.com/products/xm-direct2-interface-adapter`
 -  `yourstore.com/t/categories/headphones`

Each controller is configured to serve the content using these keyword-relevant, meaningful URLs.

### On Page Keyword Targeting

Several enhancements have been made to improve on-page keyword targeting. The admin interface provides the ability to manage meta descriptions and meta keywords at the product level. Additionally, H1 tags are used throughout the site for product and taxonomy names. The ease of extension development and layout changes allows you to target keywords throughout the site.

Taxons also have `meta_keywords` and `meta_description` on them. (You can configure these in the Admin > Configuration > Taxonomies). If you want to add keywords and description to another kind of object in Spree, you can do so simply by adding those two fields (`meta_keywords` and `meta_description`) onto the object in question. The Spree controller must instantiate an instance variable of the same class name as the controller (so, for example, `@taxon` for the TaxonsController) for this to work. Check out the `meta_data` method in [base_helper.rb](https://github.com/spree/spree/blob/master/core/app/helpers/spree/base_helper.rb) for details on how that works. 

### Clean Content

Spree uses Bootstrap which is a responsive CSS framework that allows clean HTML that also responds well to any screen size. Having clean HTML with minimal inline JavaScript and CSS is considered to be a factor in search engine optimization.

### On Site Performance Optimization

Spree has been configured to serve one CSS and one JavaScript file on
every page (excluding extension inclusions). Minimizing HTTP requests is
considered an important factor in search engine optimization as the
server performance is an important influence in the search engine crawl
behavior for a site.

### Google Analytics integration

To integrate with Google Analytics you need to install [Analytic Trackers](https://github.com/spree-contrib/spree_analytics_trackers) extension.

## Gotchas, Known Issues, and Further Considerations

### Spree SEO Extensions

The following list shows extensions that can improve search engine
performance. Refer to the GitHub README for developer notes.

- [Spree Sitemap Generator](https://github.com/spree-contrib/spree_sitemap)
- [Static Content Management](https://github.com/spree-contrib/spree_static_content)
- [Product Reviews](https://github.com/spree-contrib/spree_reviews)
