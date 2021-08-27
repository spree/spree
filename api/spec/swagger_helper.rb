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
      openapi: '3.0.1',
      info: {
        title: 'Platform API V2',
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
      components: {
        securitySchemes: {
          bearer_auth: {
            type: :http,
            scheme: :bearer
          }
        },
        schemas: {
          address_params: {
            type: :object,
            properties: {
              country_id: { type: :string },
              state_id: { type: :string },
              state_name: { type: :string },
              address1: { type: :string },
              city: { type: :string },
              zipcode: { type: :string },
              phone: { type: :string },
              alternative_phone: { type: :string },
              firstname: { type: :string },
              lastname: { type: :string },
              label: { type: :string },
              company: { type: :string },
              user_id: { type: :string }
            }
          },
          classification_params: {
            type: :object,
            properties: {
              product_id: { type: :string },
              taxon_id: { type: :string },
              position: { type: :integer }
            }
          },
          option_type_params: {
            type: :object,
            properties: {
              name: { type: :string },
              presentation: { type: :string }
            },
            required: %w[name presentation]
          },
          option_value_params: {
            type: :object,
            properties: {
              name: { type: :string },
              presentation: { type: :string },
              option_values_attributes: { type: :string }
            },
            required: %w[name presentation]
          },
          product_params: {
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
              taxon_ids: { type: :string }
            },
            required: %w[name price shipping_category_id]
          },
          user_params: {
            type: :object,
            properties: {
              email: { type: :string },
              password: { type: :string },
              password_confirmation: { type: :string },
              ship_address_id: { type: :string },
              bill_address_id: { type: :string },
            },
            required: %w[email password password_confirmation]
          },
          taxon_params: {
            type: :object,
            properties: {
              taxonomy_id: { type: :string },
              parent_id: { type: :string },
              name: { type: :string }
            },
            required: %w[name taxonomy_id]
          },
          menu_params: {
            type: :object,
            properties: {
              name: { type: :string },
              location: { type: :string },
              locale: { type: :string }
            },
            required: %w[name location locale]
          },
          menu_item_params: {
            type: :object,
            properties: {
              name: { type: :string },
              code: { type: :string },
              subtitle: { type: :string },
              destination: { type: :string },
              new_window: { type: :boolean },
              item_type: { type: :string },
              linked_resource_type: {type: :string},
              linked_resource_id: {type: :integer}
            },
            required: %w[name]
          },
          menu_item_reposition_params: {
            type: :object,
            properties: {
              new_parent_id: {type: :integer},
              new_position_idx: {type: :integer}
            },
            required: %w[name]
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
            required: %w[data meta links]
          },
          resource_properties: {
            type: :object,
            properties: {
              id: { type: :string },
              type: { type: :string },
              attributes: { type: :object },
              relationships: { type: :object }
            },
            required: %w[id type attributes relationships]
          },
          resource: {
            type: :object,
            properties: {
              data: { '$ref' => '#/components/schemas/resource_properties' },
            },
            required: %w[data]
          },
          error: {
            type: :object,
            properties: {
              error: { type: :string },
            },
            required: %w[error]
          },
          validation_errors: {
            type: :object,
            properties: {
              error: { type: :string },
              errors: { type: :object }
            },
            required: %w[error errors]
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
    next if response.nil? || response.body.blank?

    example.metadata[:response][:content] = {
      'application/vnd.api+json' => {
        examples: {
          'Example': {
            value: JSON.parse(response.body, symbolize_names: true)
          }
        }
      }
    }
  end
end
