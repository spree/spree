# frozen_string_literal: true

require 'spec_helper'
require 'rswag/specs'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.swagger_root = Rails.root.join('../../docs').to_s # Rails.root is a dummy app

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under swagger_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a swagger_doc tag to the
  # the root example_group in your specs, e.g. describe '...', swagger_doc: 'v2/swagger.json'
  config.swagger_docs = {
    'v2/platform/index.yaml' => {
      openapi: '3.0.3',
      info: {
        title: 'Platform API',
        contact: {
          name: 'Spark Solutions',
          url: 'https://sparksolutions.co',
          email: 'we@sparksolutions.co',
        },
        description: 'Spree Platform API',
        version: 'v2'
      },
      paths: {},
      servers: [
        {
          url: 'https://{defaultHost}',
          variables: {
            defaultHost: {
              default: 'localhost:3000'
            }
          }
        }
      ],
      tags: [
        { name: 'Addresses' },
        { name: 'Adjustments' },
        { name: 'Classifications' },
        { name: 'Countries' },
        { name: 'CMS Pages' },
        { name: 'CMS Sections' },
        { name: 'Digital Assets' },
        { name: 'Digital Links' },
        { name: 'Line Items' },
        { name: 'Menus' },
        { name: 'Menu Items' },
        { name: 'Option Types' },
        { name: 'Option Values' },
        { name: 'Orders' },
        { name: 'Payments' },
        { name: 'Payment Methods' },
        { name: 'Promotion Categories' },
        { name: 'Shipments' },
        { name: 'Shipping Categories' },
        { name: 'Shipping Methods' },
        { name: 'Taxons' },
        { name: 'Users' },
        { name: 'Webhook Events' },
        { name: 'Webhook Subscribers' },
        { name: 'Wishlists' },
        { name: 'Wished Items' },
        { name: 'Variants' }
      ],
      components: {
        securitySchemes: {
          bearer_auth: {
            type: :http,
            scheme: :bearer
          }
        },
        schemas: {

          # Address
          create_address_params: {
            type: :object,
            properties: {
              address: {
                type: :object,
                required: %w[country_id address1 city zipcode phone firstname lastname],
                properties: {
                  country_id: { type: :string, example: '224' },
                  state_id: { type: :string, example: '516' },
                  state_name: { type: :string, example: 'New York' },
                  address1: { type: :string, example: '5th ave' },
                  address2: { type: :string, example: '1st suite' },
                  city: { type: :string, example: 'NY' },
                  zipcode: { type: :string, example: '10001' },
                  phone: { type: :string, example: '+1 123 456 789' },
                  alternative_phone: { type: :string },
                  firstname: { type: :string, example: 'John' },
                  lastname: { type: :string, example: 'Snow' },
                  label: { type: :string, example: 'My home address' },
                  company: { type: :string, example: 'Vendo Cloud Inc' },
                  user_id: { type: :string },
                  public_metadata: { type: :object, example: { 'distance_from_nearest_city_in_km' => 10, 'location_type' => 'building' } },
                  private_metadata: { type: :object, example: { 'close_to_shop' => true } }
                }
              }
            },
            required: %w[address],
            'x-internal': true
          },
          update_address_params: {
            type: :object,
            properties: {
              address: {
                type: :object,
                properties: {
                  country_id: { type: :string, example: '224' },
                  state_id: { type: :string, example: '516' },
                  state_name: { type: :string, example: 'New York' },
                  address1: { type: :string, example: '5th ave' },
                  address2: { type: :string, example: '1st suite' },
                  city: { type: :string, example: 'NY' },
                  zipcode: { type: :string, example: '10001' },
                  phone: { type: :string, example: '+1 123 456 789' },
                  alternative_phone: { type: :string },
                  firstname: { type: :string, example: 'John' },
                  lastname: { type: :string, example: 'Snow' },
                  label: { type: :string, example: 'My home address' },
                  company: { type: :string, example: 'Vendo Cloud Inc' },
                  user_id: { type: :string },
                  public_metadata: { type: :object, example: { 'distance_from_city_in_km' => 10, 'location_type' => 'building' } },
                  private_metadata: { type: :object, example: { 'close_to_shop' => true } }
                }
              }
            },
            required: %w[address],
            'x-internal': true
          },

          # Adjustment
          create_adjustment_params: {
            type: :object,
            properties: {
              adjustment: {
                type: :object,
                required: %w[order_id label adjustable_id adjustable_type],
                properties: {
                  order_id: { type: :string },
                  label: { type: :string, example: 'Shipping costs' },
                  adjustable_id: { type: :string },
                  adjustable_type: { type: :string, example: 'Spree::LineItem' },
                  source_id: { type: :string },
                  source_type: { type: :string, example: 'Spree::TaxRate' },
                  amount: { type: :number, example: 10.90 },
                  mandatory: { type: :boolean },
                  eligible: { type: :boolean },
                  state: { type: :string, example: 'closed', default: 'open', enum: ['closed', 'open'] },
                  included: { type: :boolean, example: true, default: false },
                }
              }
            },
            required: %w[adjustment],
            'x-internal': true
          },
          update_adjustment_params: {
            type: :object,
            properties: {
              adjustment: {
                type: :object,
                properties: {
                  order_id: { type: :string },
                  label: { type: :string, example: 'Shipping costs' },
                  adjustable_id: { type: :string },
                  adjustable_type: { type: :string, example: 'Spree::LineItem' },
                  source_id: { type: :string },
                  source_type: { type: :string, example: 'Spree::TaxRate' },
                  amount: { type: :number, example: 10.90 },
                  mandatory: { type: :boolean },
                  eligible: { type: :boolean },
                  state: { type: :string, example: 'closed', default: 'open', enum: ['closed', 'open'] },
                  included: { type: :boolean, example: true, default: false },
                }
              }
            },
            required: %w[adjustment],
            'x-internal': true
          },

          # Classification
          create_classification_params: {
            type: :object,
            properties: {
              classification: {
                type: :object,
                required: %w[product_id taxon_id position],
                properties: {
                  product_id: { type: :string, example: '1' },
                  taxon_id: { type: :string, example: '1' },
                  position: { type: :integer, example: 1 }
                }
              }
            },
            required: %w[classification],
            'x-internal': true
          },
          update_classification_params: {
            type: :object,
            properties: {
              classification: {
                type: :object,
                properties: {
                  product_id: { type: :string, example: '1' },
                  taxon_id: { type: :string, example: '1' },
                  position: { type: :integer, example: 1 }
                }
              }
            },
            required: %w[classification],
            'x-internal': true
          },

          # CMS Page
          create_standard_cms_page_params: {
            type: :object,
            properties: {
              cms_page: {
                type: :object,
                required: %w[title locale type],
                properties: {
                  title: { type: :string, example: 'About Us', description: 'Give your page a title.' },
                  type: { type: :string, enum: ['Spree::Cms::Pages::StandardPage'], description: 'Set the type of page.' },
                  meta_title: { type: :string, nullable: true, example: 'Learn More About Super-Shop', description: 'Set the meta title for this page, this appears in the title bar of the browser.' },
                  content: { type: :string, nullable: true, example: "Lot's of text..", description: 'The text content of a standard page, this can be HTML from a rich text editor.' },
                  meta_description: { type: :string, nullable: true, example: 'Learn more about us on this page here...', description: 'Set a meta description, used for SEO and displayed in search results.' },
                  visible: { type: :boolean, enum: [true, false], description: 'This page is publicly visible when set to `true`.' },
                  slug: { type: :string, nullable: true, example: 'about-us', description: 'Set a slug for this page.' },
                  locale: { type: :string, example: 'en-US', description: 'The language this page is written in.' }
                }
              }
            },
            required: %w[cms_page],
            title: 'Create a Standard Page',
            'x-internal': true
          },
          create_homepage_cms_page_params: {
            type: :object,
            properties: {
              cms_page: {
                type: :object,
                required: %w[title locale type],
                properties: {
                  title: { type: :string, example: 'Our Flash Homepage', description: 'Give your page a title.' },
                  type: { type: :string, enum: ['Spree::Cms::Pages::Homepage'], description: 'Set the type of page.' },
                  meta_title: { type: :string, nullable: true, example: 'Visit Our Store - Great Deals', description: 'Set the meta title for this page, this appears in the title bar of the browser.' },
                  meta_description: { type: :string, nullable: true, example: 'Discover great new products that we sell in this store...', description: 'Set a meta description, used for SEO and displayed in search results.' },
                  visible: { type: :boolean, enum: [true, false], description: 'This page is publicly visible when set to `true`.' },
                  locale: { type: :string, example: 'en-US', description: 'The language this page is written in.' }
                }
              }
            },
            required: %w[cms_page],
            title: 'Create a Homepage',
            'x-internal': true
          },
          create_feature_cms_page_params: {
            type: :object,
            properties: {
              cms_page: {
                type: :object,
                required: %w[title locale type],
                properties: {
                  title: { type: :string, example: 'Featured Product', description: 'Give your page a title.' },
                  type: { type: :string, enum: ['Spree::Cms::Pages::FeaturePage'], description: 'Set the type of page.' },
                  meta_title: { type: :string, nullable: true, example: 'Learn More About This Featured Product', description: 'Set the meta title for this page, this appears in the title bar of the browser.' },
                  meta_description: { type: :string, nullable: true, example: 'Learn more about us this amazing product that we sell right here...', description: 'Set a meta description, used for SEO and displayed in search results.' },
                  visible: { type: :boolean, enum: [true, false], description: 'This page is publicly visible when set to `true`.' },
                  slug: { type: :string, nullable: true, example: 'about-us', description: 'Set a slug for this page.' },
                  locale: { type: :string, example: 'en-US', description: 'The language this page is written in.' }
                }
              }
            },
            required: %w[cms_page],
            title: 'Create a Feature Page',
            'x-internal': true
          },
          update_standard_cms_page_params: {
            type: :object,
            properties: {
              cms_page: {
                type: :object,
                properties: {
                  title: { type: :string, example: 'About Us', description: 'Update the page title.' },
                  type: { type: :string, enum: ['Spree::Cms::Pages::StandardPage', 'Spree::Cms::Pages::Homepage', 'Spree::Cms::Pages::FeaturePage'], description: 'Change the type of page.' },
                  meta_title: { type: :string, nullable: true, example: 'Learn More About Super-Shop', description: 'Update the meta title for this page, this appears in the title bar of the browser.' },
                  content: { type: :string, nullable: true, example: "Lot's of text..", description: 'Update the text content of a standard page, this can be HTML from a rich text editor.' },
                  meta_description: { type: :string, nullable: true, example: 'Learn more about us on this page here...', description: 'Update the meta description, used for SEO and displayed in search results.' },
                  visible: { type: :boolean, enum: [true, false], description: 'This page is publicly visible when set to `true`.' },
                  slug: { type: :string, nullable: true, example: 'about-us', description: 'Update the slug for this page.' },
                  locale: { type: :string, example: 'en-US', description: 'Update the language of this page.' }
                }
              }
            },
            required: %w[cms_page],
            title: 'Update a Standard Page',
            'x-internal': true
          },
          update_homepage_cms_page_params: {
            type: :object,
            properties: {
              cms_page: {
                type: :object,
                properties: {
                  title: { type: :string, example: 'Our Flash Homepage', description: 'Update the page title.' },
                  type: { type: :string, enum: ['Spree::Cms::Pages::StandardPage', 'Spree::Cms::Pages::Homepage', 'Spree::Cms::Pages::FeaturePage'], description: 'Change the type of page.' },
                  meta_title: { type: :string, nullable: true, example: 'Visit Our Store - Great Deals', description: 'Update the meta title for this page, this appears in the title bar of the browser.' },
                  meta_description: { type: :string, nullable: true, example: 'Discover great new products that we sell in this store...', description: 'Update the meta description, used for SEO and displayed in search results.' },
                  visible: { type: :boolean, enum: [true, false], description: 'This page is publicly visible when set to `true`.' },
                  locale: { type: :string, example: 'en-US', description: 'Update the language of this page.' }
                }
              }
            },
            required: %w[cms_page],
            title: 'Update a Homepage',
            'x-internal': true
          },
          update_feature_cms_page_params: {
            type: :object,
            properties: {
              cms_page: {
                type: :object,
                properties: {
                  title: { type: :string, example: 'Featured Product', description: 'Update the page title.' },
                  type: { type: :string, enum: ['Spree::Cms::Pages::StandardPage', 'Spree::Cms::Pages::Homepage', 'Spree::Cms::Pages::FeaturePage'], description: 'Change the type of page.' },
                  meta_title: { type: :string, nullable: true, example: 'Learn More About This Featured Product', description: 'Update the meta title for this page, this appears in the title bar of the browser.' },
                  meta_description: { type: :string, nullable: true, example: 'Learn more about us this amazing product that we sell right here...', description: 'Update the meta description, used for SEO and displayed in search results.' },
                  visible: { type: :boolean, enum: [true, false], description: 'This page is publicly visible when set to `true`.' },
                  slug: { type: :string, nullable: true, example: 'about-us', description: 'Update the slug for this page.' },
                  locale: { type: :string, example: 'en-US', description: 'Update the language of this page.' }
                }
              }
            },
            required: %w[cms_page],
            title: 'Update a Feature Page',
            'x-internal': true
          },

          # CMS Section
          create_hero_image_cms_section_params: {
            type: :object,
            properties: {
              cms_section: {
                type: :object,
                required: %w[name cms_page_id type],
                properties: {
                  name: { type: :string, description: 'Give this section a name.' },
                  cms_page_id: { type: :string, description: 'Set the `cms_page` ID that this section belongs to.' },
                  type: { type: :string, enum: ['Spree::Cms::Sections::HeroImage'], example: 'Spree::Cms::Sections::HeroImage', description: 'Set the section type.' },
                  linked_resource_type: { type: :string, example: 'Spree::Taxon', nullable: true, enum: ['Spree::Taxon', 'Spree::Product', 'Spree::CmsPage'], description: 'Set the resource type that this section links to.' },
                  linked_resource_id: { type: :string, example: '1', nullable: true, description: 'Set the ID of the resource that you would like this section to link to.' },
                  fit: { type: :string, example: 'Screen', enum: ['Screen', 'Container'], description: 'This value is used by front end developers to set CSS classes for content that fits the screen edge-to-edge, or stays within the boundaries of the central container.' },
                  position: { type: :integer, example: 2, description: 'Pass the position that you want this section to appear in. (The list is not zero indexed, so the first item is position: `1`)' },
                  gutters: { type: :string, example: 'No Gutters', enum: ['Gutters', 'No Gutters'], description: 'This value is used by front end developers for styling the section padding.' },
                  button_text: { type: :string, example: 'Click Here', description: 'Set the text value of the button used in this section.' },
                  title: { type: :string, example: 'Shop Today', description: 'Create a title for the Hero Section.' },
                  'digital[image_one]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' }
                }
              }
            },
            required: %w[cms_section],
            title: 'Create a Hero Image Section',
            'x-internal': true
          },
          create_product_carousel_cms_section_params: {
            type: :object,
            properties: {
              cms_section: {
                type: :object,
                required: %w[name cms_page_id type],
                properties: {
                  name: { type: :string, description: 'Give this section a name.' },
                  cms_page_id: { type: :string, description: 'Set the `cms_page` ID that this section belongs to.' },
                  type: { type: :string, enum: ['Spree::Cms::Sections::ProductCarousel'], example: 'Spree::Cms::Sections::ProductCarousel', description: 'Set the section type.' },
                  position: { type: :integer, example: 2, description: 'Pass the position that you want this section to appear in. (The list is not zero indexed, so the first item is position: `1`)' },
                  linked_resource_id: { type: :string, example: '1', nullable: true, description: 'Set the ID of the Taxon that you would like displayed as a Product Carousel.' }
                }
              }
            },
            required: %w[cms_section],
            title: 'Create a Product Carousel Section',
            'x-internal': true
          },
          create_side_by_side_images_cms_section_params: {
            type: :object,
            properties: {
              cms_section: {
                type: :object,
                required: %w[name cms_page_id type],
                properties: {
                  name: { type: :string, description: 'Give this section a name.' },
                  cms_page_id: { type: :string, description: 'Set the `cms_page` ID that this section belongs to.' },
                  type: { type: :string, enum: ['Spree::Cms::Sections::SideBySideImages'], example: 'Spree::Cms::Sections::SideBySideImages', description: 'Set the section type.' },
                  position: { type: :integer, example: 2, description: 'Pass the position that you want this section to appear in. (The list is not zero indexed, so the first item is position: `1`)' },
                  link_type_one: { type: :string, example: 'Spree::Taxon', enum: ['Spree::Taxon', 'Spree::Product'], description: 'Set the resource type that image one links to.' },
                  link_type_two: { type: :string, example: 'Spree::Taxon', enum: ['Spree::Taxon', 'Spree::Product'], description: 'Set the resource type that image two links to.' },
                  link_one: { type: :string, example: 'men/shirts', nullable: true, description: 'Set the slug or path that image two links to.' },
                  link_two: { type: :string, example: 'white-shirt', nullable: true, description: 'Set the slug or path that image two links to.' },
                  title_one: { type: :string, example: "Shop Men's Shirts", nullable: true, description: 'Set the title used in image one.' },
                  title_two: { type: :string, example: "Buy This Men's Shirt", nullable: true, description: 'Set the title used in image two.' },
                  fit: { type: :string, example: 'Screen', enum: ['Screen', 'Container'], description: 'This value is used by front end developers to set CSS classes for content that fits the screen edge-to-edge, or stays within the boundaries of the central container.' },
                  subtitle_one: { type: :string, example: 'Save 50% today', nullable: true, description: 'Set the subtitle used in image one.' },
                  subtitle_two: { type: :string, example: 'Save 50% today', nullable: true, description: 'Set the subtitle used in image two.' },
                  gutters: { type: :string, example: 'No Gutters', enum: ['Gutters', 'No Gutters'], description: 'This value is used by front end developers for styling the section padding.' },
                  'digital[image_one]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' },
                  'digital[image_two]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' }
                }
              }
            },
            required: %w[cms_section],
            title: 'Create a Side-by-Side Image Section',
            'x-internal': true
          },
          create_image_gallery_cms_section_params: {
            type: :object,
            properties: {
              cms_section: {
                type: :object,
                required: %w[name cms_page_id type],
                properties: {
                  name: { type: :string, description: 'Give this section a name.' },
                  cms_page_id: { type: :string, description: 'Set the `cms_page` ID that this section belongs to.' },
                  type: { type: :string, enum: ['Spree::Cms::Sections::ImageGallery'], example: 'Spree::Cms::Sections::ImageGallery', description: 'Set the section type.' },
                  position: { type: :integer, example: 2, description: 'Pass the position that you want this section to appear in. (The list is not zero indexed, so the first item is position: `1`)' },
                  link_type_one: { type: :string, example: 'Spree::Taxon', enum: ['Spree::Taxon', 'Spree::Product'], description: 'Set the resource type that image one links to.' },
                  link_type_two: { type: :string, example: 'Spree::Taxon', enum: ['Spree::Taxon', 'Spree::Product'], description: 'Set the resource type that image two links to.' },
                  link_type_three: { type: :string, example: 'Spree::Taxon', enum: ['Spree::Taxon', 'Spree::Product'], description: 'Set the resource type that image three links to.' },
                  link_one: { type: :string, example: 'men/shirts', nullable: true, description: 'Set the slug or path that image two links to.' },
                  link_two: { type: :string, example: 'white-shirt', nullable: true, description: 'Set the slug or path that image two links to.' },
                  link_three: { type: :string, example: 'red-shirt', nullable: true, description: 'Set the slug or path that image three links to.' },
                  title_one: { type: :string, example: "Shop Men's Shirts", nullable: true, description: 'Set the title used in image one.' },
                  title_two: { type: :string, example: "Buy This Men's Shirt", nullable: true, description: 'Set the title used in image two.' },
                  title_three: { type: :string, example: "Buy This Women's Skirt", nullable: true, description: 'Set the title used in image three.' },
                  fit: { type: :string, example: 'Screen', enum: ['Screen', 'Container'], description: 'This value is used by front end developers to set CSS classes for content that fits the screen edge-to-edge, or stays within the boundaries of the central container.' },
                  layout_style: { type: :string, example: 'Default', enum: ['Default', 'Reversed'], description: 'This value is used by front end developers for styling the order the images appear.' },
                  display_labels: { type: :string, example: 'Show', enum: ['Show', 'Hide'], description: 'This value is used by front end developers for showing and hiding the label on the images.' },
                  'digital[image_one]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' },
                  'digital[image_two]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' },
                  'digital[image_three]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' }
                }
              }
            },
            required: %w[cms_section],
            title: 'Create an Image Gallery Section',
            'x-internal': true
          },
          create_featured_article_cms_section_params: {
            type: :object,
            properties: {
              cms_section: {
                type: :object,
                required: %w[name cms_page_id type],
                properties: {
                  name: { type: :string, description: 'Give this section a name.' },
                  cms_page_id: { type: :string, description: 'Set the `cms_page` ID that this section belongs to.' },
                  type: { type: :string, enum: ['Spree::Cms::Sections::FeaturedArticle'], example: 'Spree::Cms::Sections::FeaturedArticle', description: 'Set the section type.' },
                  position: { type: :integer, example: 2, description: 'Pass the position that you want this section to appear in. (The list is not zero indexed, so the first item is position: `1`)' },
                  linked_resource_type: { type: :string, example: 'Spree::Taxon', nullable: true, enum: ['Spree::Taxon', 'Spree::Product', 'Spree::CmsPage'], description: 'Set the resource type that this section links to.' },
                  linked_resource_id: { type: :string, example: '1', nullable: true, description: 'Set the ID of the resource that you would like this section to link to.' },
                  fit: { type: :string, example: 'Screen', enum: ['Screen', 'Container'], description: 'This value is used by front end developers to set CSS classes for content that fits the screen edge-to-edge, or stays within the boundaries of the central container.' },
                  gutters: { type: :string, example: 'No Gutters', enum: ['Gutters', 'No Gutters'], description: 'This value is used by front end developers for styling the section padding.' },
                  button_text: { type: :string, example: 'Click Here', description: 'Set the text value of the button used in this section.' },
                  title: { type: :string, example: 'Shop Today', description: 'Create a title for the Section.' },
                  subtitle: { type: :string, example: 'Save Big!', description: 'Create a subtitle for the Section.' },
                  rte_content: { type: :string, example: 'Lots of text and content goes here.', description: 'Set the content, here, this can be rich text editor content.' }
                }
              }
            },
            required: %w[cms_section],
            title: 'Create a Featured Article Section',
            'x-internal': true
          },
          create_rich_text_cms_section_params: {
            type: :object,
            properties: {
              cms_section: {
                type: :object,
                required: %w[name cms_page_id type],
                properties: {
                  name: { type: :string, description: 'Give this section a name.' },
                  cms_page_id: { type: :string, description: 'Set the `cms_page` ID that this section belongs to.' },
                  type: { type: :string, enum: ['Spree::Cms::Sections::RichTextContent'], example: 'Spree::Cms::Sections::RichTextContent', description: 'Set the section type.' },
                  position: { type: :integer, example: 2, description: 'Pass the position that you want this section to appear in. (The list is not zero indexed, so the first item is position: `1`)' },
                  fit: { type: :string, example: 'Screen', enum: ['Screen', 'Container'], description: 'This value is used by front end developers to set CSS classes for content that fits the screen edge-to-edge, or stays within the boundaries of the central container.' },
                  rte_content: { type: :string, example: 'Lots of text and content goes here.', description: 'Set the content, here, this can be rich text editor content.' }
                }
              }
            },
            required: %w[cms_section],
            title: 'Create a Rich Text Section',
            'x-internal': true
          },
          update_hero_image_cms_section_params: {
            type: :object,
            properties: {
              cms_section: {
                type: :object,
                properties: {
                  name: { type: :string, description: 'Update this section name.' },
                  type: { type: :string, enum: ['Spree::Cms::Sections::HeroImage', 'Spree::Cms::Sections::FeaturedArticle', 'Spree::Cms::Sections::ProductCarousel', 'Spree::Cms::Sections::ImageGallery', 'Spree::Cms::Sections::SideBySideImages', 'Spree::Cms::Sections::RichTextContent'], example: 'Spree::Cms::Sections::ProductCarousel', description: 'Change the section type.' },
                  linked_resource_type: { type: :string, example: 'Spree::Taxon', nullable: true, enum: ['Spree::Taxon', 'Spree::Product', 'Spree::CmsPage'], description: 'Update the resource type that this section links to.' },
                  linked_resource_id: { type: :string, example: '1', nullable: true, description: 'Set the ID of the resource that you would like this section to link to.' },
                  fit: { type: :string, example: 'Screen', enum: ['Screen', 'Container'], description: 'This value is used by front end developers to set CSS classes for content that fits the screen edge-to-edge, or stays within the boundaries of the central container.' },
                  position: { type: :integer, example: 2, description: 'Pass the position that you want this section to appear in. (The list is not zero indexed, so the first item is position: `1`)' },
                  gutters: { type: :string, example: 'No Gutters', enum: ['Gutters', 'No Gutters'], description: 'This value is used by front end developers for styling the section padding.' },
                  button_text: { type: :string, example: 'Click Here', description: 'Update the text value of the button used in this section.' },
                  title: { type: :string, example: 'Shop Today', description: 'Update the title for this section.' },
                  'digital[image_one]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' }

                }
              }
            },
            required: %w[cms_section],
            title: 'Update a Hero Image Section',
            'x-internal': true
          },
          update_product_carousel_cms_section_params: {
            type: :object,
            properties: {
              cms_section: {
                type: :object,
                properties: {
                  name: { type: :string, description: 'Change this section name.' },
                  type: { type: :string, enum: ['Spree::Cms::Sections::HeroImage', 'Spree::Cms::Sections::FeaturedArticle', 'Spree::Cms::Sections::ProductCarousel', 'Spree::Cms::Sections::ImageGallery', 'Spree::Cms::Sections::SideBySideImages', 'Spree::Cms::Sections::RichTextContent'], example: 'Spree::Cms::Sections::ProductCarousel', description: 'Change the section type.' },
                  position: { type: :integer, example: 2, description: 'Pass the position that you want this section to appear in. (The list is not zero indexed, so the first item is position: `1`)' },
                  linked_resource_id: { type: :string, example: '1', nullable: true, description: 'Update the ID of the Taxon that you would like displayed as a Product Carousel.' }
                }
              }
            },
            required: %w[cms_section],
            title: 'Update a Product Carousel Section',
            'x-internal': true
          },
          update_side_by_side_images_cms_section_params: {
            type: :object,
            properties: {
              cms_section: {
                type: :object,
                properties: {
                  name: { type: :string, description: 'Update this section name.' },
                  type: { type: :string, enum: ['Spree::Cms::Sections::HeroImage', 'Spree::Cms::Sections::FeaturedArticle', 'Spree::Cms::Sections::ProductCarousel', 'Spree::Cms::Sections::ImageGallery', 'Spree::Cms::Sections::SideBySideImages', 'Spree::Cms::Sections::RichTextContent'], example: 'Spree::Cms::Sections::ProductCarousel', description: 'Change the section type.' },
                  position: { type: :integer, example: 2, description: 'Pass the position that you want this section to appear in. (The list is not zero indexed, so the first item is position: `1`)' },
                  link_type_one: { type: :string, example: 'Spree::Taxon', enum: ['Spree::Taxon', 'Spree::Product'], description: 'Update the resource type that image one links to.' },
                  link_type_two: { type: :string, example: 'Spree::Taxon', enum: ['Spree::Taxon', 'Spree::Product'], description: 'Update the resource type that image two links to.' },
                  link_one: { type: :string, example: 'men/shirts', nullable: true, description: 'Update the slug or path that image two links to.' },
                  link_two: { type: :string, example: 'white-shirt', nullable: true, description: 'Update the slug or path that image two links to.' },
                  title_one: { type: :string, example: "Shop Men's Shirts", nullable: true, description: 'Update the title used in image one.' },
                  title_two: { type: :string, example: "Buy This Men's Shirt", nullable: true, description: 'Update the title used in image two.' },
                  fit: { type: :string, example: 'Screen', enum: ['Screen', 'Container'], description: 'This value is used by front end developers to set CSS classes for content that fits the screen edge-to-edge, or stays within the boundaries of the central container.' },
                  subtitle_one: { type: :string, example: 'Save 50% today', nullable: true, description: 'Update the subtitle used in image one.' },
                  subtitle_two: { type: :string, example: 'Save 50% today', nullable: true, description: 'Update the subtitle used in image two.' },
                  gutters: { type: :string, example: 'No Gutters', enum: ['Gutters', 'No Gutters'], description: 'This value is used by front end developers for styling the section padding.' },
                  'digital[image_one]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' },
                  'digital[image_two]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' }
                }
              }
            },
            required: %w[cms_section],
            title: 'Update a Side-by-Side Image Section',
            'x-internal': true
          },
          update_image_gallery_cms_section_params: {
            type: :object,
            properties: {
              cms_section: {
                type: :object,
                properties: {
                  name: { type: :string, description: 'Update this section name.' },
                  type: { type: :string, enum: ['Spree::Cms::Sections::HeroImage', 'Spree::Cms::Sections::FeaturedArticle', 'Spree::Cms::Sections::ProductCarousel', 'Spree::Cms::Sections::ImageGallery', 'Spree::Cms::Sections::SideBySideImages', 'Spree::Cms::Sections::RichTextContent'], example: 'Spree::Cms::Sections::ProductCarousel', description: 'Change the section type.' },
                  position: { type: :integer, example: 2, description: 'Pass the position that you want this section to appear in. (The list is not zero indexed, so the first item is position: `1`)' },
                  link_type_one: { type: :string, example: 'Spree::Taxon', enum: ['Spree::Taxon', 'Spree::Product'], description: 'Update the resource type that image one links to.' },
                  link_type_two: { type: :string, example: 'Spree::Taxon', enum: ['Spree::Taxon', 'Spree::Product'], description: 'Update the resource type that image two links to.' },
                  link_type_three: { type: :string, example: 'Spree::Taxon', enum: ['Spree::Taxon', 'Spree::Product'], description: 'Update the resource type that image three links to.' },
                  link_one: { type: :string, example: 'men/shirts', nullable: true, description: 'Update the slug or path that image two links to.' },
                  link_two: { type: :string, example: 'white-shirt', nullable: true, description: 'Update the slug or path that image two links to.' },
                  link_three: { type: :string, example: 'red-shirt', nullable: true, description: 'Update the slug or path that image three links to.' },
                  title_one: { type: :string, example: "Shop Men's Shirts", nullable: true, description: 'Update the title used in image one.' },
                  title_two: { type: :string, example: "Buy This Men's Shirt", nullable: true, description: 'Update the title used in image two.' },
                  title_three: { type: :string, example: "Buy This Women's Skirt", nullable: true, description: 'Update the title used in image three.' },
                  fit: { type: :string, example: 'Screen', enum: ['Screen', 'Container'], description: 'This value is used by front end developers to set CSS classes for content that fits the screen edge-to-edge, or stays within the boundaries of the central container.' },
                  layout_style: { type: :string, example: 'Default', enum: ['Default', 'Reversed'], description: 'This value is used by front end developers for styling the order the images appear.' },
                  display_labels: { type: :string, example: 'Show', enum: ['Show', 'Hide'], description: 'This value is used by front end developers for showing and hiding the label on the images.' },
                  'digital[image_one]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' },
                  'digital[image_two]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' },
                  'digital[image_three]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' }
                }
              }
            },
            required: %w[cms_section],
            title: 'Update an Image Gallery Section',
            'x-internal': true
          },
          update_featured_article_cms_section_params: {
            type: :object,
            properties: {
              cms_section: {
                type: :object,
                properties: {
                  name: { type: :string, description: 'Update this section name.' },
                  type: { type: :string, enum: ['Spree::Cms::Sections::HeroImage', 'Spree::Cms::Sections::FeaturedArticle', 'Spree::Cms::Sections::ProductCarousel', 'Spree::Cms::Sections::ImageGallery', 'Spree::Cms::Sections::SideBySideImages', 'Spree::Cms::Sections::RichTextContent'], example: 'Spree::Cms::Sections::ProductCarousel', description: 'Change the section type.' },
                  position: { type: :integer, example: 2, description: 'Pass the position that you want this section to appear in. (The list is not zero indexed, so the first item is position: `1`)' },
                  linked_resource_type: { type: :string, example: 'Spree::Taxon', nullable: true, enum: ['Spree::Taxon', 'Spree::Product', 'Spree::CmsPage'], description: 'Set the resource type that this section links to.' },
                  linked_resource_id: { type: :string, example: '1', nullable: true, description: 'Change the ID of the resource that you would like this section to link to.' },
                  fit: { type: :string, example: 'Screen', enum: ['Screen', 'Container'], description: 'This value is used by front end developers to set CSS classes for content that fits the screen edge-to-edge, or stays within the boundaries of the central container.' },
                  gutters: { type: :string, example: 'No Gutters', enum: ['Gutters', 'No Gutters'], description: 'This value is used by front end developers for styling the section padding.' },
                  button_text: { type: :string, example: 'Click Here', description: 'Update the text value of the button used in this section.' },
                  title: { type: :string, example: 'Shop Today', description: 'Update the title for the Section.' },
                  subtitle: { type: :string, example: 'Save Big!', description: 'Update the subtitle for the Section.' },
                  rte_content: { type: :string, example: 'Lots of text and content goes here.', description: 'Update the content here, this can be rich text editor content.' }
                }
              }
            },
            required: %w[cms_section],
            title: 'Update a Featured Article Section',
            'x-internal': true
          },
          update_rich_text_cms_section_params: {
            type: :object,
            properties: {
              cms_section: {
                type: :object,
                properties: {
                  name: { type: :string, description: 'Update this section name.' },
                  type: { type: :string, enum: ['Spree::Cms::Sections::HeroImage', 'Spree::Cms::Sections::FeaturedArticle', 'Spree::Cms::Sections::ProductCarousel', 'Spree::Cms::Sections::ImageGallery', 'Spree::Cms::Sections::SideBySideImages', 'Spree::Cms::Sections::RichTextContent'], example: 'Spree::Cms::Sections::ProductCarousel', description: 'Change the section type.' },
                  position: { type: :integer, example: 2, description: 'Pass the position that you want this section to appear in. (The list is not zero indexed, so the first item is position: `1`)' },
                  fit: { type: :string, example: 'Screen', enum: ['Screen', 'Container'], description: 'This value is used by front end developers to set CSS classes for content that fits the screen edge-to-edge, or stays within the boundaries of the central container.' },
                  rte_content: { type: :string, example: 'Lots of text and content goes here.', description: 'Update the content, here, this can be rich text editor content.' }
                }
              }
            },
            required: %w[cms_section],
            title: 'Update a Rich Text Section',
            'x-internal': true
          },

          # Digital
          create_digital_params: {
            type: :object,
            properties: {
              'digital[attachment]': { type: :string, format: :binary },
              "digital[variant_id]": { type: :string, example: '123' }
            },
            required: ['digital[attachment]', 'digital[variant_id]'],
            'x-internal': true
          },
          update_digital_params: {
            type: :object,
            properties: {
              'digital[attachment]': { type: :string, format: :binary },
              "digital[variant_id]": { type: :string, example: '123' }
            },
            required: ['digital[attachment]', 'digital[variant_id]'],
            'x-internal': true
          },

          # Digital Link
          create_digital_link_params: {
            type: :object,
            properties: {
              digital_link: {
                type: :object,
                required: %w[line_item_id digital_id],
                properties: {
                  access_counter: { type: :integer, example: 0 },
                  line_item_id: { type: :string, example: '1' },
                  digital_id: { type: :string, example: '1' }
                }
              }
            },
            required: %w[digital_link],
            'x-internal': true
          },
          update_digital_link_params: {
            type: :object,
            properties: {
              digital_link: {
                type: :object,
                properties: {
                  access_counter: { type: :integer, example: 0 },
                  line_item_id: { type: :string, example: '1' },
                  digital_id: { type: :string, example: '1' }
                }
              }
            },
            required: %w[digital_link],
            'x-internal': true
          },

          # Line Item
          create_line_item_params: {
            type: :object,
            properties: {
              line_item: {
                type: :object,
                required: %w[order_id variant_id quantity],
                properties: {
                  order_id: { type: :string, example: '1' },
                  variant_id: { type: :string, example: '1' },
                  quantity: { type: :integer, example: 2 }
                }
              }
            },
            required: %w[line_item],
            'x-internal': true
          },
          # TODO: Check these are correct.
          update_line_item_params: {
            type: :object,
            properties: {
              line_item: {
                type: :object,
                properties: {
                  variant_id: { type: :string, example: '1' },
                  quantity: { type: :integer, example: 2 }
                }
              }
            },
            required: %w[line_item],
            'x-internal': true
          },

          # Menu
          create_menu_params: {
            type: :object,
            properties: {
              menu: {
                type: :object,
                required: %w[name location locale],
                properties: {
                  name: { type: :string, example: 'Main Menu', description: 'Give this Menu a name.' },
                  location: { type: :string, enum: ['header', 'footer'], description: 'Set the location this menu appears in the website.' },
                  locale: { type: :string, example: 'en-US', description: 'Set the language of this menu.' }
                }
              }
            },
            required: %w[menu],
            'x-internal': true
          },
          update_menu_params: {
            type: :object,
            properties: {
              menu: {
                type: :object,
                properties: {
                  name: { type: :string, example: 'Main Menu', description: 'Update this Menu name.' },
                  location: { type: :string, enum: ['header', 'footer'], description: 'Update the location this menu appears in the website.' },
                  locale: { type: :string, example: 'en-US', description: 'Change the language of this menu.' }
                }
              }
            },
            required: %w[menu],
            'x-internal': true
          },

          # Menu Item
          create_menu_item_params: {
            type: :object,
            properties: {
              menu_item: {
                type: :object,
                required: %w[name menu_id],
                properties: {
                  name: { type: :string, example: 'T-Shirts', description: 'The name of this Menu Item'},
                  code: { type: :string, nullable: true, example: 'MEN-TS', description: 'Give this Menu Item a code to identify this Menu Item from others. This is especially useful when using Container type Menu Items to group items.' },
                  subtitle: { type: :string, nullable: true, example: "Shop men's T-Shirts", description: 'Set an optional subtitle for the Menu Item, this is useful if your menu has promotional links that require more than just a link name.' },
                  destination: { type: :string, nullable: true, example: 'https://getvendo.com', description: 'Used when the linked_resource_type is set to: URL' },
                  menu_id: { type: :integer, example: 1, description: 'Specify the ID of the Menu this item belongs to.' },
                  new_window: { type: :boolean, description: 'When set to `true` the link will be opened in a new tab or window.' },
                  item_type: { type: :string, enum: ['Link', 'Container'], description: 'Links are standard links, where as Containers are used to group links.' },
                  linked_resource_type: { type: :string, enum: ['URL', 'Spree::Taxon', 'Spree::Product', 'Spree::CmsPage'], description: 'Set the type of resource you want to link to, or set to: URL to use the destination field for an external link.' },
                  linked_resource_id: { type: :integer, example: 1, nullable: true, description: 'The ID of the resource you are linking to.' }
                }
              }
            },
            required: %w[menu_item],
            title: 'Create a Menu Item',
            'x-internal': true
          },
          update_menu_item_params: {
            type: :object,
            properties: {
              menu_item: {
                type: :object,
                properties: {
                  name: { type: :string, example: 'T-Shirts', description: 'Update the name of this Menu Item'},
                  code: { type: :string, nullable: true, example: 'MEN-TS', description: 'The Menu Item a code to identifies this Menu Item from others. This is especially useful when using Container type Menu Items to group items.' },
                  subtitle: { type: :string, nullable: true, example: "Shop men's T-Shirts", description: 'Set an optional subtitle for the Menu Item, this is useful if your menu has promotional links that require more than just a link name.' },
                  destination: { type: :string, nullable: true, example: 'https://getvendo.com', description: 'Used when the linked_resource_type is set to: URL' },
                  menu_id: { type: :integer, example: 1, description: 'Specify the ID of the Menu this item belongs to.' },
                  new_window: { type: :boolean, description: 'When set to `true` the link will be opened in a new tab or window.' },
                  item_type: { type: :string, enum: ['Link', 'Container'], description: 'Links are standard links, where as Containers are used to group links.' },
                  linked_resource_type: { type: :string, enum: ['URL', 'Spree::Taxon', 'Spree::Product', 'Spree::CmsPage'], description: 'Change the type of resource you want to link to, or set to: URL to use the destination field for an external link.' },
                  linked_resource_id: { type: :integer, example: 1, nullable: true, description: 'The ID of the resource you are linking to.' }
                }
              }
            },
            required: %w[menu_item],
            title: 'Update a Menu Item',
            'x-internal': true
          },
          menu_item_reposition: {
            type: :object,
            properties: {
              menu_item: {
                type: :object,
                required: %w[new_parent_id new_position_idx],
                properties: {
                  new_parent_id: { type: :integer, example: 1, description: 'The ID of the new target parent Menu Item.' },
                  new_position_idx: { type: :integer, example: 1, description: 'The new index position of the Menu Item within its parent' }
                }
              }
            },
            required: %w[menu_item],
            title: 'Reposition a Menu Item',
            'x-internal': true
          },

          # Option Type
          create_option_type_params: {
            type: :object,
            properties: {
              option_type: {
                type: :object,
                required: %w[name presentation],
                properties: {
                  name: { type: :string, example: 'color' },
                  presentation: { type: :string, example: 'Color' },
                  public_metadata: { type: :object },
                  private_metadata: { type: :object }
                }
              }
            },
            required: %w[option_type],
            'x-internal': true
          },
          update_option_type_params: {
            type: :object,
            properties: {
              option_type: {
                type: :object,
                properties: {
                  name: { type: :string, example: 'color' },
                  presentation: { type: :string, example: 'Color' },
                  public_metadata: { type: :object },
                  private_metadata: { type: :object }
                }
              }
            },
            required: %w[option_type],
            'x-internal': true
          },

          # Option Value
          create_option_value_params: {
            type: :object,
            properties: {
              option_value: {
                type: :object,
                required: %w[name presentation],
                properties: {
                  name: { type: :string, example: 'red' },
                  presentation: { type: :string, example: 'Red' },
                  public_metadata: { type: :object },
                  private_metadata: { type: :object }
                }
              }
            },
            required: %w[option_value],
            'x-internal': true
          },
          update_option_value_params: {
            type: :object,
            properties: {
              option_value: {
                type: :object,
                properties: {
                  name: { type: :string, example: 'red' },
                  presentation: { type: :string, example: 'Red' },
                  public_metadata: { type: :object },
                  private_metadata: { type: :object }
                }
              }
            },
            required: %w[option_value],
            'x-internal': true
          },

          # Order
          create_order_params: {
            type: :object,
            properties: {
              order: {
                type: :object,
                properties: {
                  item_total: { type: :number, example: 170.90 },
                  total: { type: :number, example: 190.90 },
                  state: { type: :string, example: 'complete', enum: %w[cart address delivery payment confirm complete canceled] },
                  adjustment_total: { type: :number, example: 20.0 },
                  user_id: { type: :string, example: '1' },
                  completed_at: { type: :string, format: :date_time, example: Time.current },
                  bill_address_id: { type: :string, example: '1' },
                  ship_address_id: { type: :string, example: '1' },
                  payment_total: { type: :number, example: 190.90 },
                  shipment_state: { type: :string, example: 'shipped', enum: Spree::Order::SHIPMENT_STATES },
                  payment_state: { type: :string, example: 'paid', enum: Spree::Order::PAYMENT_STATES },
                  email: { type: :string, format: :email, example: 'hi@getvendo.com' },
                  special_instructions: { type: :string, example: 'I need it ASAP!' },
                  currency: { type: :string, example: 'USD' },
                  last_ip_address: { type: :string, example: '127.0.0.1' },
                  created_by_id: { type: :string, example: '1' },
                  shipment_total: { type: :number, example: 10.0 },
                  additional_tax_total: { type: :number, example: 10.0 },
                  promo_total: { type: :number, example: 0.0 },
                  channel: { type: :string, example: 'online' },
                  included_tax_total: { type: :number, example: 0.0 },
                  item_count: { type: :integer, example: 2 },
                  approver_id: { type: :string },
                  approved_at: { type: :string, format: :date_time, example: Time.current },
                  confirmation_delivered: { type: :boolean, example: true, default: false },
                  considered_risky: { type: :boolean, example: true, default: false },
                  canceled_at: { type: :string, format: :date_time },
                  canceler_id: { type: :string },
                  taxable_adjustment_total: { type: :number, example: 170.90 },
                  non_taxable_adjustment_total: { type: :number, example: 10.0 },
                  store_owner_notification_delivered: { type: :boolean, example: true, default: false },
                  bill_address_attributes: { '$ref': '#/components/schemas/update_address_params' },
                  ship_address_attributes: { '$ref': '#/components/schemas/update_address_params' },
                  line_items_attributes: {
                    type: :array,
                    items: { '$ref': '#/components/schemas/update_line_item_params' }
                  }
                }
              }
            },
            required: %w[order],
            'x-internal': true
          },
          update_order_params: {
            type: :object,
            properties: {
              order: {
                type: :object,
                properties: {
                  item_total: { type: :number, example: 170.90 },
                  total: { type: :number, example: 190.90 },
                  state: { type: :string, example: 'complete', enum: %w[cart address delivery payment confirm complete canceled] },
                  adjustment_total: { type: :number, example: 20.0 },
                  user_id: { type: :string, example: '1' },
                  completed_at: { type: :string, format: :date_time, example: Time.current },
                  bill_address_id: { type: :string, example: '1' },
                  ship_address_id: { type: :string, example: '1' },
                  payment_total: { type: :number, example: 190.90 },
                  shipment_state: { type: :string, example: 'shipped', enum: Spree::Order::SHIPMENT_STATES },
                  payment_state: { type: :string, example: 'paid', enum: Spree::Order::PAYMENT_STATES },
                  email: { type: :string, format: :email, example: 'hi@getvendo.com' },
                  special_instructions: { type: :string, example: 'I need it ASAP!' },
                  currency: { type: :string, example: 'USD' },
                  last_ip_address: { type: :string, example: '127.0.0.1' },
                  created_by_id: { type: :string, example: '1' },
                  shipment_total: { type: :number, example: 10.0 },
                  additional_tax_total: { type: :number, example: 10.0 },
                  promo_total: { type: :number, example: 0.0 },
                  channel: { type: :string, example: 'online' },
                  included_tax_total: { type: :number, example: 0.0 },
                  item_count: { type: :integer, example: 2 },
                  approver_id: { type: :string },
                  approved_at: { type: :string, format: :date_time, example: Time.current },
                  confirmation_delivered: { type: :boolean, example: true, default: false },
                  considered_risky: { type: :boolean, example: true, default: false },
                  canceled_at: { type: :string, format: :date_time },
                  canceler_id: { type: :string },
                  taxable_adjustment_total: { type: :number, example: 170.90 },
                  non_taxable_adjustment_total: { type: :number, example: 10.0 },
                  store_owner_notification_delivered: { type: :boolean, example: true, default: false },
                  bill_address_attributes: { '$ref': '#/components/schemas/update_address_params' },
                  ship_address_attributes: { '$ref': '#/components/schemas/update_address_params' },
                  line_items_attributes: {
                    type: :array,
                    items: { '$ref': '#/components/schemas/update_line_item_params' }
                  }
                }
              }
            },
            required: %w[order],
            'x-internal': true
          },

          # Payment Method
          create_payment_method_params: {
            type: :object,
            properties: {
              payment_method: {
                type: :object,
                required: %w[name],
                properties: {
                  name: { type: :string, example: 'Test Payment Method' },
                  active: { type: :boolean },
                  auto_capture: { type: :boolean },
                  description: { type: :string, example: 'This is a test payment method' },
                  type: { type: :string, example: 'Spree::Gateway::Bogus', enum: ['Spree::Gateway::Bogus', 'Spree::PaymentMethod::Check'] },
                  display_on: { type: :string, example: 'both', enum: ['both', 'back_end', 'front_end'] },
                  store_ids: {
                    type: :array,
                    items: {
                      allOf: [
                        { type: :string, example: '2' }
                      ]
                    }
                  },
                  public_metadata: { type: :object },
                  private_metadata: { type: :object }
                }
              }
            },
            required: %w[payment_method],
            'x-internal': true
          },
          update_payment_method_params: {
            type: :object,
            properties: {
              payment_method: {
                type: :object,
                properties: {
                  name: { type: :string, example: 'Test Payment Method' },
                  active: { type: :boolean },
                  auto_capture: { type: :boolean },
                  description: { type: :string, example: 'This is a test payment method' },
                  type: { type: :string, example: 'Spree::Gateway::Bogus', enum: ['Spree::Gateway::Bogus', 'Spree::PaymentMethod::Check'] },
                  display_on: { type: :string, example: 'both', enum: ['both', 'back_end', 'front_end'] },
                  store_ids: {
                    type: :array,
                    items: {
                      allOf: [
                        { type: :string, example: '2' }
                      ]
                    }
                  },
                  public_metadata: { type: :object },
                  private_metadata: { type: :object }
                }
              }
            },
            required: %w[payment_method],
            'x-internal': true,
            title: 'Update Payment Method'
          },
          update_payment_method_params_bogus_gateway: {
            type: :object,
            properties: {
              payment_method: {
                type: :object,
                properties: {
                  preferred_dummy_key: { type: :string, example: 'UPDATED-DUMMY-KEY-123' },
                  preferred_server: { type: :string, example: 'production' },
                  preferred_test_mode: { type: :boolean },
                }
              }
            },
            required: %w[payment_method],
            'x-internal': true,
            title: 'Update Bogus Gateway'
          },

          # Product
          create_product_params: {
            type: :object,
            properties: {
              product: {
                type: :object,
                required: %w[name price shipping_category_id],
                properties: {
                  name: { type: :string },
                  description: { type: :string },
                  available_on: { type: :string },
                  discontinue_on: { type: :string },
                  permalink: { type: :string },
                  meta_description: { type: :string },
                  meta_keywords: { type: :string },
                  price: { type: :string },
                  sku: { type: :string },
                  deleted_at: { type: :string },
                  prototype_id: { type: :string },
                  option_values_hash: { type: :string },
                  weight: { type: :string },
                  height: { type: :string },
                  width: { type: :string },
                  depth: { type: :string },
                  shipping_category_id: { type: :string },
                  tax_category_id: { type: :string },
                  cost_currency: { type: :string },
                  cost_price: { type: :string },
                  compare_at_price: { type: :string },
                  option_type_ids: { type: :string },
                  taxon_ids: { type: :string },
                  public_metadata: { type: :object },
                  private_metadata: { type: :object }
                }
              }
            },
            required: %w[product],
            'x-internal': true
          },
          update_product_params: {
            type: :object,
            properties: {
              product: {
                type: :object,
                properties: {
                  name: { type: :string },
                  description: { type: :string },
                  available_on: { type: :string },
                  discontinue_on: { type: :string },
                  permalink: { type: :string },
                  meta_description: { type: :string },
                  meta_keywords: { type: :string },
                  price: { type: :string },
                  sku: { type: :string },
                  deleted_at: { type: :string },
                  prototype_id: { type: :string },
                  option_values_hash: { type: :string },
                  weight: { type: :string },
                  height: { type: :string },
                  width: { type: :string },
                  depth: { type: :string },
                  shipping_category_id: { type: :string },
                  tax_category_id: { type: :string },
                  cost_currency: { type: :string },
                  cost_price: { type: :string },
                  compare_at_price: { type: :string },
                  option_type_ids: { type: :string },
                  taxon_ids: { type: :string },
                  public_metadata: { type: :object },
                  private_metadata: { type: :object }
                }
              }
            },
            required: %w[product],
            'x-internal': true
          },

          # Promotion Category
          create_promotion_category_params: {
            type: :object,
            properties: {
              promotion_category: {
                type: :object,
                required: %w[name],
                properties: {
                  name: { type: :string, example: 'Promotions Used in 2021' },
                  code: { type: :string, example: '2021-PROMOS' }
                }
              }
            },
            required: %w[promotion_category],
            'x-internal': true
          },
          update_promotion_category_params: {
            type: :object,
            properties: {
              promotion_category: {
                type: :object,
                required: %w[name],
                properties: {
                  name: { type: :string, example: 'Promotions Used in 2021' },
                  code: { type: :string, example: '2021-PROMOS' }
                }
              }
            },
            required: %w[promotion_category],
            'x-internal': true
          },

          # Shipping Category
          create_shipping_category_params: {
            type: :object,
            properties: {
              shipping_category: {
                type: :object,
                required: %w[name],
                properties: {
                  name: { type: :string, example: 'Another Category' }
                }
              }
            },
            required: %w[shipping_category],
            'x-internal': true
          },
          update_shipping_category_params: {
            type: :object,
            properties: {
              shipping_category: {
                type: :object,
                required: %w[name],
                properties: {
                  name: { type: :string, example: 'Another Category' }
                }
              }
            },
            required: %w[shipping_category],
            'x-internal': true
          },

          # Shipping Method
          create_shipping_method_params: {
            type: :object,
            properties: {
              shipping_method: {
                type: :object,
                required: %w[name display_on shipping_category_ids],
                properties: {
                  name: { type: :string, example: 'DHL Express' },
                  admin_name: { type: :string, example: 'DHL Area Code D' },
                  code: { type: :string, example: 'DHL-A-D' },
                  tracking_url: { type: :string, example: 'dhlexpress.com?tracking=' },
                  display_on: { type: :string, example: 'both', enum: ['both', 'back_end', 'front_end'] },
                  tax_category_id: { type: :string, example: '1' },
                  shipping_category_ids: {
                    type: :array,
                    items: {
                      allOf: [
                        { type: :string, example: '2' }
                      ]
                    }
                  },
                  calculator_attributes: { '$ref': '#/components/schemas/shipping_calculator_params' },
                }
              }
            },
            required: %w[shipping_method],
            'x-internal': true
          },
          update_shipping_method_params: {
            type: :object,
            properties: {
              shipping_method: {
                type: :object,
                properties: {
                  name: { type: :string, example: 'DHL Express' },
                  admin_name: { type: :string, example: 'DHL Area Code D' },
                  code: { type: :string, example: 'DHL-A-D' },
                  tracking_url: { type: :string, example: 'dhlexpress.com?tracking=' },
                  display_on: { type: :string, example: 'both', enum: ['both', 'back_end', 'front_end'] },
                  tax_category_id: { type: :string, example: '1' },
                  shipping_category_ids: {
                    type: :array,
                    items: {
                      allOf: [
                        { type: :string, example: '2' }
                      ]
                    }
                  },
                  calculator_attributes: { '$ref': '#/components/schemas/shipping_calculator_params' },
                }
              }
            },
            required: %w[shipping_method],
            'x-internal': true
          },
          shipping_calculator_params: {
            type: :object,
            properties: {
              type: { type: :string, example: 'Spree::Calculator::Shipping::FlatPercentItemTotal', enum: ['Spree::Calculator::Shipping::DigitalDelivery', 'Spree::Calculator::Shipping::FlatPercentItemTotal', 'Spree::Calculator::Shipping::FlatRate', 'Spree::Calculator::Shipping::FlexiRate', 'Spree::Calculator::Shipping::PerItem', 'Spree::Calculator::Shipping::PriceSack'] }
            },
            required: %w[type],
            'x-internal': true
          },

          # Taxon
          create_taxon_params: {
            type: :object,
            properties: {
              taxon: {
                type: :object,
                required: %w[name taxonomy_id],
                properties: {
                  taxonomy_id: { type: :string },
                  parent_id: { type: :string },
                  name: { type: :string },
                  public_metadata: { type: :object, example: { 'ability_to_recycle' => '90%' } },
                  private_metadata: { type: :object, example: { 'profitability' => 2 } }
                }
              }
            },
            required: %w[taxon],
            'x-internal': true
          },
          update_taxon_params: {
            type: :object,
            properties: {
              taxon: {
                type: :object,
                properties: {
                  taxonomy_id: { type: :string },
                  parent_id: { type: :string },
                  name: { type: :string },
                  public_metadata: { type: :object },
                  private_metadata: { type: :object }
                }
              }
            },
            required: %w[taxon],
            'x-internal': true
          },

          # User
          create_user_params: {
            type: :object,
            properties: {
              user: {
                type: :object,
                required: %w[email password password_confirmation],
                properties: {
                  email: { type: :string },
                  password: { type: :string },
                  password_confirmation: { type: :string },
                  ship_address_id: { type: :string },
                  bill_address_id: { type: :string },
                }
              }
            },
            required: %w[user],
            'x-internal': true
          },
          update_user_params: {
            type: :object,
            properties: {
              user: {
                type: :object,
                properties: {
                  email: { type: :string },
                  password: { type: :string },
                  password_confirmation: { type: :string },
                  ship_address_id: { type: :string },
                  bill_address_id: { type: :string },
                }
              }
            },
            required: %w[user],
            'x-internal': true
          },

          # Webhook
          create_webhook_subscriber_params: {
            type: :object,
            properties: {
              subscriber: {
                type: :object,
                required: %w[url],
                properties: {
                  active: { type: :boolean, example: true, default: false },
                  subscriptions: {
                    type: :array,
                    items: {
                      allOf: [
                        { type: :string, example: 'order.completed' }
                      ]
                    },
                    example: ['order.created', 'order.completed', 'product.updated'],
                    default: []
                  },
                  url: { type: :string, example: 'https://www.url.com/' }
                }
              }
            },
            required: %w[subscriber],
            'x-internal': true
          },
          update_webhook_subscriber_params: {
            type: :object,
            properties: {
              subscriber: {
                type: :object,
                required: %w[url],
                properties: {
                  active: { type: :boolean, example: true, default: false },
                  subscriptions: {
                    type: :array,
                    items: {
                      allOf: [
                        { type: :string, example: 'order.completed' }
                      ]
                    },
                    example: ['order.created', 'order.completed', 'product.updated'],
                    default: []
                  },
                  url: { type: :string, example: 'https://www.url.com/' }
                }
              }
            },
            required: %w[subscriber],
            'x-internal': true
          },

          # Wishlist
          create_wishlist_params: {
            type: :object,
            properties: {
              wishlist: {
                type: :object,
                required: %w[name user_id],
                properties: {
                  name: { type: :string },
                  user_id: { type: :string },
                  is_default: { type: :boolean },
                  is_private: { type: :boolean }
                }
              }
            },
            required: %w[wishlist],
            'x-internal': true
          },
          update_wishlist_params: {
            type: :object,
            properties: {
              wishlist: {
                type: :object,
                properties: {
                  name: { type: :string },
                  user_id: { type: :string },
                  is_default: { type: :boolean },
                  is_private: { type: :boolean }
                }
              }
            },
            required: %w[wishlist],
            'x-internal': true
          },

          # Wished Item
          create_wished_item_params: {
            type: :object,
            properties: {
              wished_item: {
                type: :object,
                required: %w[wishlist_id variant_id quantity],
                properties: {
                  wishlist_id: { type: :string },
                  variant_id: { type: :string },
                  quantity: {
                    type: :integer,
                    description: 'Must be an integer greater than 0'
                  }
                }
              }
            },
            required: %w[wished_item],
            'x-internal': true
          },
          update_wished_item_params: {
            type: :object,
            properties: {
              wished_item: {
                type: :object,
                required: %w[wishlist_id variant_id quantity],
                properties: {
                  wishlist_id: { type: :string },
                  variant_id: { type: :string },
                  quantity: {
                    type: :integer,
                    description: 'Must be an integer greater than 0'
                  }
                }
              }
            },
            required: %w[wished_item],
            'x-internal': true
          },

          # Nested Parameters
          amount_param: {
            type: :object,
            properties: {
              amount: { type: :number }
            },
            'x-internal': true
          },

          coupon_code_param: {
            type: :object,
            properties: {
              coupon_code: { type: :string }
            },
            'x-internal': true
          },
          resources_list: {
            type: :object,
            properties: {
              data: {
                type: :array,
                items: {
                  allOf: [
                    { '$ref' => '#/components/schemas/resource_properties' }
                  ]
                }
              },
              meta: {
                type: :object,
                properties: {
                  count: { type: :integer },
                  total_count: { type: :integer },
                  total_pages: { type: :integer }
                },
                required: %w[count total_count total_pages]
              },
              links: {
                type: :object,
                properties: {
                  self: { type: :string },
                  next: { type: :string },
                  prev: { type: :string },
                  last: { type: :string },
                  first: { type: :string }
                },
                required: %w[self next prev last first]
              }
            },
            required: %w[data meta links],
            'x-internal': true
          },
          resource_properties: {
            type: :object,
            properties: {
              id: { type: :string },
              type: { type: :string },
              attributes: { type: :object },
              relationships: { type: :object }
            },
            required: %w[id type attributes],
            'x-internal': true
          },
          resource: {
            type: :object,
            properties: {
              data: { '$ref' => '#/components/schemas/resource_properties' },
            },
            required: %w[data],
            'x-internal': true
          },
          error: {
            type: :object,
            properties: {
              error: { type: :string },
            },
            required: %w[error],
            'x-internal': true
          },
          validation_errors: {
            type: :object,
            properties: {
              error: { type: :string },
              errors: { type: :object }
            },
            required: %w[error errors],
            'x-internal': true
          }
        }
      }
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The swagger_docs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.swagger_format = :yaml

  # auto generate examples based on response
  config.after do |example|
    next if example.metadata[:swagger].nil?
    next if response.nil? || response.body.blank? || example.metadata[:response][:schema].nil?

    example.metadata[:response][:content] = {
      'application/vnd.api+json' => {
        examples: {
          'Example': {
            value: JSON.parse(response.body, symbolize_names: true)
          },
        },
        schema: {
          '$ref': example.metadata[:response][:schema]['$ref']
        }
      }
    }
  end
end
