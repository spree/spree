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
          url: 'http://{defaultHost}',
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
        { name: 'Products' },
        { name: 'Promotions' },
        { name: 'Promotion Actions' },
        { name: 'Promotion Categories' },
        { name: 'Promotion Rules' },
        { name: 'Roles' },
        { name: 'Shipments' },
        { name: 'Shipping Categories' },
        { name: 'Shipping Methods' },
        { name: 'States' },
        { name: 'Stock Items' },
        { name: 'Stock Locations' },
        { name: 'Store Credit Categories' },
        { name: 'Store Credit Types' },
        { name: 'Store Credits' },
        { name: 'Tax Categories' },
        { name: 'Tax Rates' },
        { name: 'Taxons' },
        { name: 'Taxonomies' },
        { name: 'Users' },
        { name: 'Variants' },
        { name: 'Webhook Events' },
        { name: 'Webhook Subscribers' },
        { name: 'Wishlists' },
        { name: 'Wished Items' },
        { name: 'Zones' }
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
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
                  'cms_section[image_one]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' }
                }
              }
            },
            required: %w[cms_section],
            title: 'Create a Hero Image Section',
            'x-internal': false
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
            'x-internal': false
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
                  'cms_section[image_one]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' },
                  'cms_section[image_two]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' }
                }
              }
            },
            required: %w[cms_section],
            title: 'Create a Side-by-Side Image Section',
            'x-internal': false
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
                  'cms_section[image_one]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' },
                  'cms_section[image_two]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' },
                  'cms_section[image_three]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' }
                }
              }
            },
            required: %w[cms_section],
            title: 'Create an Image Gallery Section',
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
                  'cms_section[image_one]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' }

                }
              }
            },
            required: %w[cms_section],
            title: 'Update a Hero Image Section',
            'x-internal': false
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
            'x-internal': false
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
                  'cms_section[image_one]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' },
                  'cms_section[image_two]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' }
                }
              }
            },
            required: %w[cms_section],
            title: 'Update a Side-by-Side Image Section',
            'x-internal': false
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
                  'cms_section[image_one]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' },
                  'cms_section[image_two]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' },
                  'cms_section[image_three]': { type: :string, format: :binary, description: 'Use a `multipart/form-data` request to upload assets.' }
                }
              }
            },
            required: %w[cms_section],
            title: 'Update an Image Gallery Section',
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
          },

          # Digital
          create_digital_params: {
            type: :object,
            properties: {
              'digital[attachment]': { type: :string, format: :binary },
              "digital[variant_id]": { type: :string, example: '123' }
            },
            required: ['digital[attachment]', 'digital[variant_id]'],
            'x-internal': false
          },
          update_digital_params: {
            type: :object,
            properties: {
              'digital[attachment]': { type: :string, format: :binary },
              "digital[variant_id]": { type: :string, example: '123' }
            },
            required: ['digital[attachment]', 'digital[variant_id]'],
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
                  quantity: { type: :integer, example: 2 },
                  public_metadata: { type: :object },
                  private_metadata: { type: :object }
                }
              }
            },
            required: %w[line_item],
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
          },

          # Menu Item
          create_menu_item_params: {
            type: :object,
            properties: {
              menu_item: {
                type: :object,
                required: %w[name menu_id],
                properties: {
                  name: { type: :string, example: 'T-Shirts', description: 'The name of this Menu Item' },
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
            'x-internal': false
          },
          update_menu_item_params: {
            type: :object,
            properties: {
              menu_item: {
                type: :object,
                properties: {
                  name: { type: :string, example: 'T-Shirts', description: 'Update the name of this Menu Item' },
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
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
                  },
                  public_metadata: { type: :object },
                  private_metadata: { type: :object }
                }
              }
            },
            required: %w[order],
            'x-internal': false
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
                  },
                  public_metadata: { type: :object },
                  private_metadata: { type: :object }
                }
              }
            },
            required: %w[order],
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false,
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
            'x-internal': false,
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
            'x-internal': false
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
            'x-internal': false
          },

          # Promotion
          create_promotion_params: {
            type: :object,
            properties: {
              promotion: {
                type: :object,
                required: %w[name],
                properties: {
                  name: { type: :string, example: 'Promotions Used in 2021', description: 'Give the promotion a name.' },
                  code: { type: :string, example: 'BLK-FRI', nullable: true, description: 'Set the promotion code. Promotions without a code are automatically applied if the order meets the Promotion Rule requirements.' },
                  description: { type: :string, example: 'Save today with discount code XYZ at checkout.', nullable: true, description: 'Give the promotion a description.' },
                  usage_limit: { type: :integer, example: 100, nullable: true, description: 'If you wish you can set a usage limit for this promotion.' },
                  advertise: { type: :boolean },
                  starts_at: { type: :string, format: :date_time, nullable: true, description: 'Set a date and time that this promotion begins.' },
                  ends_at: { type: :string, format: :date_time, nullable: true, description: 'Set a date and time that this promotion ends.' },
                  store_ids: {
                    type: :array,
                    items: {
                      allOf: [
                        { type: :string, example: '2' }
                      ]
                    }
                  }
                }
              }
            },
            required: %w[promotion],
            title: 'Create a Promotion',
            'x-internal': false
          },
          update_promotion_params: {
            type: :object,
            properties: {
              promotion: {
                type: :object,
                properties: {
                  name: { type: :string, example: 'Promotions Used in 2021', description: 'Change the promotion a name.' },
                  code: { type: :string, example: 'CYB-MON', nullable: true, description: 'Change or remove the promotion code. Promotions without a code are automatically applied if the order meets the Promotion Rule requirements.' },
                  description: { type: :string, example: 'Save today with discount code XYZ at checkout.', nullable: true, description: 'Update the promotion a description.' },
                  usage_limit: { type: :integer, example: 100, nullable: true, description: 'If you wish you can set a usage limit for this promotion.' },
                  advertise: { type: :boolean },
                  starts_at: { type: :string, format: :date_time, nullable: true, description: 'Set a date and time that this promotion begins.' },
                  ends_at: { type: :string, format: :date_time, nullable: true, description: 'Set a date and time that this promotion ends.' },
                  store_ids: {
                    type: :array,
                    items: {
                      allOf: [
                        { type: :string, example: '2' }
                      ]
                    }
                  }
                }
              }
            },
            required: %w[promotion],
            title: 'Update a Promotion',
            'x-internal': false
          },
          update_promotion_add_rule_params: {
            type: :object,
            properties: {
              promotion: {
                type: :object,
                properties: {
                  promotion_rules_attributes: {
                    type: :array,
                    items: {
                      allOf: [
                        properties: {
                          type: { type: :string, example: 'Spree::Promotion::Rules::Country', enum: ['Spree::Promotion::Rules::Country', 'Spree::Promotion::Rules::ItemTotal', 'Spree::Promotion::Rules::Product', 'Spree::Promotion::Rules::User', 'Spree::Promotion::Rules::FirstOrder', 'Spree::Promotion::Rules::UserLoggedIn', 'Spree::Promotion::Rules::OneUsePerUser', 'Spree::Promotion::Rules::Taxon', 'Spree::Promotion::Rules::OptionValue'], description: 'Set the Promotion Rule type.' },
                          preferred_country_id: { type: :integer, example: 122, description: 'Each rule type has its own preferred attributes. In this example we are setting the ID of the Country this rule applies to. To learn more about Spree preferences visit TODO: [LINK].' },
                        }
                      ]
                    }
                  }
                }
              }
            },
            required: %w[promotion],
            title: 'Add a Rule to a Promotion',
            'x-internal': false
          },
          update_promotion_update_rule_params: {
            type: :object,
            properties: {
              promotion: {
                type: :object,
                properties: {
                  promotion_rules_attributes: {
                    type: :array,
                    items: {
                      allOf: [
                        properties: {
                          id: { type: :string, example: '22', description: 'To update an existing Promotion Rule, you are required to pass the ID of the rule you are updating.' },
                          type: { type: :string, example: 'Spree::Promotion::Rules::Country', enum: ['Spree::Promotion::Rules::Country', 'Spree::Promotion::Rules::ItemTotal', 'Spree::Promotion::Rules::Product', 'Spree::Promotion::Rules::User', 'Spree::Promotion::Rules::FirstOrder', 'Spree::Promotion::Rules::UserLoggedIn', 'Spree::Promotion::Rules::OneUsePerUser', 'Spree::Promotion::Rules::Taxon', 'Spree::Promotion::Rules::OptionValue'], description: 'Set the Promotion Rule type.' },
                          preferred_country_id: { type: :integer, example: 143, description: 'Each rule type has its own preferred attributes. In this example we are changing the ID of the Country this rule applies to. To learn more about Spree preferences visit TODO: [LINK].' }
                        }
                      ]
                    }
                  }
                }
              }
            },
            required: %w[promotion],
            title: 'Update an existing Rule',
            'x-internal': false
          },
          update_promotion_add_action_params: {
            type: :object,
            properties: {
              promotion: {
                type: :object,
                properties: {
                  promotion_actions_attributes: {
                    type: :array,
                    items: {
                      allOf: [
                        properties: {
                          type: { type: :string, example: 'Spree::Promotion::Actions::CreateAdjustment', enum: ['Spree::Promotion::Actions::CreateAdjustment', 'Spree::Promotion::Actions::CreateItemAdjustments', 'Spree::Promotion::Actions::FreeShipping', 'Spree::Promotion::Actions::CreateLineItems'], description: 'Set the Promotion Action Type.' },
                        }
                      ]
                    }
                  }
                }
              }
            },
            required: %w[promotion],
            title: 'Add an Action to a Promotion',
            'x-internal': false
          },
          update_promotion_action_calculator_params: {
            type: :object,
            properties: {
              promotion: {
                type: :object,
                properties: {
                  promotion_actions_attributes: {
                    type: :array,
                    items: {
                      allOf: [
                        properties: {
                          id: { type: :string, example: '22', description: 'To update an existing Promotion Action, you are required to pass the ID of the action you wish to update.' },
                          calculator_attributes: {
                            properties: {
                              id: { type: :string, example: '19', description: 'To update an existing Action Calculator, you are required to pass the ID of the calculator.' },
                              type: { type: :string, example: 'Spree::Promotion::Actions::CreateAdjustment', enum: ['Spree::Promotion::Actions::CreateAdjustment', 'Spree::Promotion::Actions::CreateItemAdjustments', 'Spree::Promotion::Actions::CreateLineItems', 'Spree::Promotion::Actions::FreeShipping'], description: 'Set the Type of Promotion Action you wish to use.' },
                              preferred_flat_percent: { type: :integer, example: 10, description: 'In this example we are setting the preferred flat percentage to `10`.' }
                            }
                          }
                        }
                      ]
                    }
                  }
                }
              }
            },
            required: %w[promotion],
            title: 'Update an Action Calculator',
            'x-internal': false
          },
          update_promotion_change_calculator_params: {
            type: :object,
            properties: {
              promotion: {
                type: :object,
                properties: {
                  promotion_actions_attributes: {
                    type: :array,
                    items: {
                      allOf: [
                        properties: {
                          id: { type: :string, example: '22', description: 'To update an existing Promotion Action, you are required to pass the ID of the Promotion Action.' },
                          calculator_attributes: {
                            properties: {
                              type: { type: :string, example: 'Spree::Calculator::FlatPercentItemTotal', enum: ['Spree::Calculator::FlatPercentItemTotal', 'Spree::Calculator::FlatRate', 'Spree::Calculator::FlexiRate', 'Spree::Calculator::TieredPercent', 'Spree::Calculator::TieredFlatRate', 'Spree::Calculator::PercentOnLineItem'], description: 'To set the Promotion Action Calculator pass the calculator type. Each Promotion action has certain Calculators available, to learn more visit TODO: [LINK]' },
                            }
                          }
                        }
                      ]
                    }
                  }
                }
              }
            },
            required: %w[promotion],
            title: 'Change an Action Calculator',
            'x-internal': false
          },
          update_promotion_change_action_params: {
            type: :object,
            properties: {
              promotion: {
                type: :object,
                properties: {
                  promotion_actions_attributes: {
                    type: :array,
                    items: {
                      allOf: [
                        properties: {
                          id: { type: :string, example: '22', description: 'To update an existing Promotion Action, you are required to pass the ID of the Promotion Action.' },
                          type: { type: :string, example: 'Spree::Promotion::Actions::CreateAdjustment', enum: ['Spree::Promotion::Actions::CreateAdjustment', 'Spree::Promotion::Actions::CreateItemAdjustments', 'Spree::Promotion::Actions::CreateLineItems', 'Spree::Promotion::Actions::FreeShipping'], description: 'Set the Type of Promotion Action you wish to use.' },
                        }
                      ]
                    }
                  }
                }
              }
            },
            required: %w[promotion],
            title: 'Change an Action Type',
            'x-internal': false
          },

          # Promotion Action
          create_promotion_action_params: {
            type: :object,
            properties: {
              promotion_action: {
                type: :object,
                required: %w[type promotion_id],
                properties: {
                  type: { type: :string, example: 'Spree::Promotion::Actions::CreateAdjustment', enum: ['Spree::Promotion::Actions::CreateAdjustment', 'Spree::Promotion::Actions::CreateItemAdjustments', 'Spree::Promotion::Actions::CreateLineItems', 'Spree::Promotion::Actions::FreeShipping'], description: 'Set the Type of Promotion Action you wish to use.' },
                  promotion_id: {type: :string, example: '22', description: 'Set the ID of the promotion this action belongs to.'}
                }
              }
            },
            required: %w[promotion_action],
            title: 'Create a Promotion Action',
            'x-internal': false
          },
          update_promotion_action_params: {
            type: :object,
            properties: {
              promotion_action: {
                type: :object,
                properties: {
                  type: { type: :string, example: 'Spree::Promotion::Actions::CreateAdjustment', enum: ['Spree::Promotion::Actions::CreateAdjustment', 'Spree::Promotion::Actions::CreateItemAdjustments', 'Spree::Promotion::Actions::CreateLineItems', 'Spree::Promotion::Actions::FreeShipping'], description: 'Set the Type of Promotion Action you wish to use.' }
                }
              }
            },
            required: %w[promotion_action],
            title: 'Create a Promotion Action',
            'x-internal': false
          },

          # Promotion Category
          create_promotion_category_params: {
            type: :object,
            properties: {
              promotion_category: {
                type: :object,
                required: %w[name],
                properties: {
                  name: { type: :string, example: 'Promotions Used in 2021', description: 'Give this Promotion Category a name.' },
                  code: { type: :string, example: '2021-PROMOS', nullable: true, description: 'Give this promotion category a code.' }
                }
              }
            },
            required: %w[promotion_category],
            'x-internal': false
          },
          update_promotion_category_params: {
            type: :object,
            properties: {
              promotion_category: {
                type: :object,
                required: %w[name],
                properties: {
                  name: { type: :string, example: 'Promotions Used in 2021', description: 'Update the name of this Promotion Category.' },
                  code: { type: :string, example: '2021-PROMOS', nullable: true, description: 'Change or remove the code for this Promotion Category.' }
                }
              }
            },
            required: %w[promotion_category],
            'x-internal': false
          },

          # Promotion Rule
          create_promotion_rule_params: {
            type: :object,
            properties: {
              promotion_rule: {
                type: :object,
                required: %w[type promotion_id],
                properties: {
                  promotion_id: {type: :string, example: '22', description: 'Set the ID of the promotion this Promotion Rule belongs to.'},
                  type: { type: :string, example: 'Spree::Promotion::Rules::Country', enum: ['Spree::Promotion::Rules::Country', 'Spree::Promotion::Rules::ItemTotal', 'Spree::Promotion::Rules::Product', 'Spree::Promotion::Rules::User', 'Spree::Promotion::Rules::FirstOrder', 'Spree::Promotion::Rules::UserLoggedIn', 'Spree::Promotion::Rules::OneUsePerUser', 'Spree::Promotion::Rules::Taxon', 'Spree::Promotion::Rules::OptionValue'], description: 'Set the Promotion Rule type.' },
                }
              }
            },
            required: %w[promotion_rule],
            title: 'Create a Promotion Rule',
            'x-internal': false
          },
          update_promotion_rule_params: {
            type: :object,
            properties: {
              promotion_rule: {
                type: :object,
                properties: {
                  type: { type: :string, example: 'Spree::Promotion::Rules::Country', enum: ['Spree::Promotion::Rules::Country', 'Spree::Promotion::Rules::ItemTotal', 'Spree::Promotion::Rules::Product', 'Spree::Promotion::Rules::User', 'Spree::Promotion::Rules::FirstOrder', 'Spree::Promotion::Rules::UserLoggedIn', 'Spree::Promotion::Rules::OneUsePerUser', 'Spree::Promotion::Rules::Taxon', 'Spree::Promotion::Rules::OptionValue'], description: 'Set the Promotion Rule type.' },
                }
              }
            },
            required: %w[promotion_rule],
            title: 'Create a Promotion Rule',
            'x-internal': false
          },

          # Role
          create_role_params: {
            type: :object,
            properties: {
              role: {
                type: :object,
                required: %w[name],
                properties: {
                  name: { type: :string, example: 'vendor' }
                }
              }
            },
            required: %w[zone],
            'x-internal': false
          },
          update_role_params: {
            type: :object,
            properties: {
              role: {
                type: :object,
                properties: {
                  name: { type: :string, example: 'vendor' },
                }
              }
            },
            required: %w[zone],
            'x-internal': false
          },

          # Shopment
          create_shipment_params: {
            type: :object,
            properties: {
              shipment: {
                type: :object,
                required: %w[stock_location_id order_id variant_id],
                properties: {
                  stock_location_id: { type: :string, example: '101' },
                  order_id: { type: :string, example: '101' },
                  variant_id: { type: :string, example: '101' },
                  quantity: { type: :integer, example: 2 }
                }
              }
            },
            required: %w[shipping_category],
            'x-internal': false
          },
          update_shipment_params: {
            type: :object,
            properties: {
              shipment: {
                type: :object,
                properties: {
                  tracking: { type: :string, example: 'MY-TRACKING-REF-12324' }
                }
              }
            },
            required: %w[shipping_category],
            'x-internal': false
          },
          add_item_shipment_params: {
            type: :object,
            properties: {
              shipment: {
                type: :object,
                required: %w[variant_id],
                properties: {
                  variant_id: { type: :string, example: '101' },
                  quantity: { type: :integer, example: 2 }
                }
              }
            },
            required: %w[shipping_category],
            'x-internal': false
          },
          remove_item_shipment_params: {
            type: :object,
            properties: {
              shipment: {
                type: :object,
                required: %w[variant_id],
                properties: {
                  variant_id: { type: :string, example: '101' },
                  quantity: { type: :integer, example: 2 }
                }
              }
            },
            required: %w[shipping_category],
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
                  public_metadata: { type: :object },
                  private_metadata: { type: :object }
                }
              }
            },
            required: %w[shipping_method],
            'x-internal': false
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
                  public_metadata: { type: :object },
                  private_metadata: { type: :object }
                }
              }
            },
            required: %w[shipping_method],
            'x-internal': false
          },
          shipping_calculator_params: {
            type: :object,
            properties: {
              type: { type: :string, example: 'Spree::Calculator::Shipping::FlatPercentItemTotal', enum: ['Spree::Calculator::Shipping::DigitalDelivery', 'Spree::Calculator::Shipping::FlatPercentItemTotal', 'Spree::Calculator::Shipping::FlatRate', 'Spree::Calculator::Shipping::FlexiRate', 'Spree::Calculator::Shipping::PerItem', 'Spree::Calculator::Shipping::PriceSack'] }
            },
            required: %w[type],
            'x-internal': false
          },

          # Stock Item
          create_stock_item_params: {
            type: :object,
            properties: {
              stock_item: {
                type: :object,
                required: %w[variant_id stock_location_id count_on_hand],
                properties: {
                  variant_id: { type: :string, example: '2' },
                  stock_location_id: { type: :string, example: '2' },
                  count_on_hand: { type: :number, example: 200 },
                  backorderable: { type: :boolean, example: true, default: false }
                }
              }
            },
            required: %w[stock_item],
            'x-internal': false
          },
          update_stock_item_params: {
            type: :object,
            properties: {
              stock_item: {
                type: :object,
                required: %w[variant_id stock_location_id count_on_hand],
                properties: {
                  variant_id: { type: :string, example: '2' },
                  stock_location_id: { type: :string, example: '2' },
                  count_on_hand: { type: :number, example: 200 },
                  backorderable: { type: :boolean, example: true, default: false }
                }
              }
            },
            required: %w[stock_item],
            'x-internal': false
          },

          # Stock Location
          create_stock_location_params: {
            type: :object,
            properties: {
              stock_location: {
                type: :object,
                required: %w[name],
                properties: {
                  name: { type: :string, example: 'Warehouse 3' },
                  default: { type: :boolean },
                  address1: { type: :string, example: 'South St. 8' },
                  address2: { type: :string, example: 'South St. 109' },
                  country_id: { type: :string, example: '2' },
                  state_id: { type: :string, example: '4' },
                  city: { type: :string, example: 'Los Angeles' },
                  state_name: { type: :string, example: 'California' },
                  zipcode: { type: :string, example: '90005' },
                  phone: { type: :string, example: '23333456' },
                  active: { type: :boolean },
                  backorderable_default: { type: :boolean },
                  propagate_all_variants: { type: :boolean },
                  admin_name: { type: :string },
                }
              }
            },
            required: %w[stock_location],
            'x-internal': false
          },
          update_stock_location_params: {
            type: :object,
            properties: {
              stock_location: {
                type: :object,
                required: %w[name],
                properties: {
                  name: { type: :string, example: 'Warehouse 3' },
                  default: { type: :boolean },
                  address1: { type: :string, example: 'South St. 8' },
                  address2: { type: :string, example: 'South St. 109' },
                  country_id: { type: :string, example: '2' },
                  state_id: { type: :string, example: '4' },
                  city: { type: :string, example: 'Los Angeles' },
                  state_name: { type: :string, example: 'California' },
                  zipcode: { type: :string, example: '90005' },
                  phone: { type: :string, example: '23333456' },
                  active: { type: :boolean },
                  backorderable_default: { type: :boolean },
                  propagate_all_variants: { type: :boolean },
                  admin_name: { type: :string },
                }
              }
            },
            required: %w[stock_location],
            'x-internal': false
          },

          # Store Credit Category
          create_store_credit_category_params: {
            type: :object,
            properties: {
              store_credit_category: {
                type: :object,
                required: %w[name],
                properties: {
                  name: { type: :string, example: 'refunded' },
                }
              }
            },
            required: %w[store_credit_category],
            'x-internal': false
          },
          update_store_credit_category_params: {
            type: :object,
            properties: {
              store_credit_category: {
                type: :object,
                required: %w[name],
                properties: {
                  name: { type: :string, example: 'refunded' },
                }
              }
            },
            required: %w[store_credit_category],
            'x-internal': false
          },

          # Store Credit Type
          create_store_credit_type_params: {
            type: :object,
            properties: {
              store_credit_type: {
                type: :object,
                required: %w[name],
                properties: {
                  name: { type: :string, example: 'refunded' },
                  priority: { type: :integer, example: 1 }
                }
              }
            },
            required: %w[store_credit_type],
            'x-internal': false
          },
          update_store_credit_type_params: {
            type: :object,
            properties: {
              store_credit_type: {
                type: :object,
                properties: {
                  name: { type: :string, example: 'refunded' },
                  priority: { type: :integer, example: 1 }
                }
              }
            },
            required: %w[store_credit_type],
            'x-internal': false
          },

          # Store Credit
          create_store_credit_params: {
            type: :object,
            properties: {
              store_credit: {
                type: :object,
                required: %w[user_id category_id type_id created_by_id currency store_id amount],
                properties: {
                  user_id: { type: :string, example: '2' },
                  category_id: { type: :string, example: '4' },
                  created_by_id: { type: :string, example: '5' },
                  amount: { type: :number, example: 25.0 },
                  amount_used: { type: :number, example: 10.0 },
                  memo: { type: :string, example: 'This credit was given as a refund' },
                  currency: { type: :string, example: 'USD' },
                  amount_authorized: { type: :number, example: 15.5 },
                  originator_id: { type: :string, example: '3' },
                  originator_type: { type: :string, example: 'Refund' },
                  type_id: { type: :string, example: '1' },
                  store_id: { type: :string, example: '2' },
                  public_metadata: { type: :object },
                  private_metadata: { type: :object }
                }
              }
            },
            required: %w[store_credit],
            'x-internal': false
          },
          update_store_credit_params: {
            type: :object,
            properties: {
              store_credit: {
                type: :object,
                required: %w[user_id category_id type_id created_by_id currency store_id amount],
                properties: {
                  user_id: { type: :string, example: '2' },
                  category_id: { type: :string, example: '4' },
                  created_by_id: { type: :string, example: '5' },
                  amount: { type: :number, example: 25.0 },
                  amount_used: { type: :number, example: 10.0 },
                  memo: { type: :string, example: 'This credit was given as a refund' },
                  currency: { type: :string, example: 'USD' },
                  amount_authorized: { type: :number, example: 15.5 },
                  originator_id: { type: :string, example: '3' },
                  originator_type: { type: :string, example: 'Refund' },
                  type_id: { type: :string, example: '1' },
                  store_id: { type: :string, example: '2' },
                  public_metadata: { type: :object },
                  private_metadata: { type: :object }
                }
              }
            },
            required: %w[store_credit],
            'x-internal': false
          },

          # Tax Category
          create_tax_category_params: {
            type: :object,
            properties: {
              tax_category: {
                type: :object,
                required: %w[name],
                properties: {
                  name: { type: :string, example: 'Clothing' },
                  is_default: { type: :boolean, example: true },
                  tax_code: { type: :string, example: '1257L' },
                  description: { type: :string, example: "Men's, women's and children's branded clothing" }
                }
              }
            },
            required: %w[tax_category],
            'x-internal': false
          },
          update_tax_category_params: {
            type: :object,
            properties: {
              tax_category: {
                type: :object,
                required: %w[name],
                properties: {
                  name: { type: :string, example: 'Clothing' },
                  is_default: { type: :boolean, example: true },
                  tax_code: { type: :string, example: '1257L' },
                  description: { type: :string, example: "Men's, women's and children's branded clothing" }
                }
              }
            },
            required: %w[tax_category],
            'x-internal': false
          },

          # Tax Rate
          create_tax_rate_params: {
            type: :object,
            properties: {
              tax_rate: {
                type: :object,
                required: %w[amount calculator_attributes tax_category_id],
                properties: {
                  amount: { type: :number, example: 0.05 },
                  zone_id: { type: :string, example: '2' },
                  tax_category_id: { type: :string, example: '1' },
                  included_in_price: { type: :boolean, example: true },
                  name: { type: :string, example: 'California' },
                  show_rate_in_label: { type: :boolean, example: false },
                  calculator_attributes: {
                    type: :object,
                    properties: {
                      type: { type: :string, example: 'Spree::Calculator::FlatRate' },
                      preferences: {
                        type: :object,
                        example: { amount: 0, currency: 'USD' }
                      },
                    }
                  }
                }
              }
            },
            required: %w[tax_rate],
            'x-internal': false
          },
          update_tax_rate_params: {
            type: :object,
            properties: {
              tax_rate: {
                type: :object,
                required: %w[amount calculator_attributes tax_category_id],
                properties: {
                  amount: { type: :number, example: 0.05 },
                  zone_id: { type: :string, example: '2' },
                  tax_category_id: { type: :string, example: '1' },
                  included_in_price: { type: :boolean, example: true },
                  name: { type: :string, example: 'California' },
                  show_rate_in_label: { type: :boolean, example: false },
                  calculator_attributes: {
                    type: :object,
                    properties: {
                      type: { type: :string, example: 'Spree::Calculator::FlatRate' },
                      preferences: {
                        type: :object,
                        example: { amount: 0, currency: 'USD' }
                      },
                    }
                  }
                }
              }
            },
            required: %w[tax_rate],
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
          },
          taxon_reposition: {
            type: :object,
            properties: {
              taxon: {
                type: :object,
                required: %w[new_parent_id new_position_idx],
                properties: {
                  new_parent_id: { type: :integer, example: 1, description: 'The ID of the new target parent Taxon.' },
                  new_position_idx: { type: :integer, example: 1, description: 'The new index position of the Taxon within the parent Taxon.' }
                }
              }
            },
            required: %w[taxon],
            title: 'Reposition a Taxon',
            'x-internal': false
          },

          # Taxonomies
          create_taxonomy_params: {
            type: :object,
            properties: {
              taxonomy: {
                type: :object,
                required: %w[name],
                properties: {
                  name: { type: :string },
                  position: { type: :integer, example: 2, description: 'Pass the position that you want this Taxonomy to appear in. (The list is not zero indexed, so the first item is position: `1`)' },
                  public_metadata: { type: :object, example: { 'ability_to_recycle' => '90%' } },
                  private_metadata: { type: :object, example: { 'profitability' => 2 } }
                }
              }
            },
            required: %w[taxonomy],
            'x-internal': false
          },
          update_taxonomy_params: {
            type: :object,
            properties: {
              taxonomy: {
                type: :object,
                properties: {
                  name: { type: :string },
                  position: { type: :integer, example: 2, description: 'Pass the position that you want this Taxonomy to appear in. (The list is not zero indexed, so the first item is position: `1`)' },
                  public_metadata: { type: :object, example: { 'ability_to_recycle' => '90%' } },
                  private_metadata: { type: :object, example: { 'profitability' => 2 } }
                }
              }
            },
            required: %w[taxonomy],
            'x-internal': false
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
                  first_name: { type: :string },
                  last_name: { type: :string },
                  password: { type: :string },
                  password_confirmation: { type: :string },
                  ship_address_id: { type: :string },
                  bill_address_id: { type: :string },
                  public_metadata: { type: :object },
                  private_metadata: { type: :object }
                }
              }
            },
            required: %w[user],
            'x-internal': false
          },
          update_user_params: {
            type: :object,
            properties: {
              user: {
                type: :object,
                properties: {
                  email: { type: :string },
                  first_name: { type: :string },
                  last_name: { type: :string },
                  password: { type: :string },
                  password_confirmation: { type: :string },
                  ship_address_id: { type: :string },
                  bill_address_id: { type: :string },
                  public_metadata: { type: :object },
                  private_metadata: { type: :object }
                }
              }
            },
            required: %w[user],
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
          },

          # Zones
          create_zone_params: {
            type: :object,
            properties: {
              zone: {
                type: :object,
                required: %w[name],
                properties: {
                  name: { type: :string, example: 'EU' },
                  description: { type: :string, example: 'All countries in the EU' },
                  default_tax: { type: :boolean },
                  kind: { type: :string, example: 'state', enum: %w[state country] }
                }
              }
            },
            required: %w[zone],
            'x-internal': false
          },
          update_zone_params: {
            type: :object,
            properties: {
              address: {
                type: :object,
                properties: {
                  name: { type: :string, example: 'EU' },
                  description: { type: :string, example: 'All countries in the EU' },
                  default_tax: { type: :boolean },
                  kind: { type: :string, example: 'state', enum: %w[state country] }
                }
              }
            },
            required: %w[zone],
            'x-internal': false
          },

          # Nested Parameters
          amount_param: {
            type: :object,
            properties: {
              amount: { type: :number }
            },
            'x-internal': false
          },

          coupon_code_param: {
            type: :object,
            properties: {
              coupon_code: { type: :string }
            },
            'x-internal': false
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
            'x-internal': false
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
            'x-internal': false
          },
          resource: {
            type: :object,
            properties: {
              data: { '$ref' => '#/components/schemas/resource_properties' },
            },
            required: %w[data],
            'x-internal': false
          },
          error: {
            type: :object,
            properties: {
              error: { type: :string },
            },
            required: %w[error],
            'x-internal': false
          },
          validation_errors: {
            type: :object,
            properties: {
              error: { type: :string },
              errors: { type: :object }
            },
            required: %w[error errors],
            'x-internal': false
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
