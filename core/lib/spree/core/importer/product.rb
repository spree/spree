module Spree
  module Core
    module Importer
      class Product
        attr_reader :product, :product_attrs, :variants_attrs, :options_attrs

        def initialize(product, product_params, options = {})
          @product = product || Spree::Product.new(product_params)

          @product_attrs = product_params.to_h
          @variants_attrs = (options[:variants_attrs] || []).map(&:to_h)
          @options_attrs = options[:options_attrs] || []
        end

        def create
          if product.save
            variants_attrs.each do |variant_attribute|
              # make sure the product is assigned before the options=
              product.variants.create({ product: product }.merge(variant_attribute))
            end

            set_up_options
          end

          product
        end

        def update
          if product.update_attributes(product_attrs)
            variants_attrs.each do |variant_attribute|
              # update the variant if the id is present in the payload
              if variant_attribute['id'].present?
                product.variants.find(variant_attribute['id'].to_i).update_attributes(variant_attribute)
              else
                # make sure the product is assigned before the options=
                product.variants.create({ product: product }.merge(variant_attribute))
              end
            end

            set_up_options
          end

          product
        end

        private

        def set_up_options
          options_attrs.each do |name|
            option_type = Spree::OptionType.where(name: name).first_or_initialize do |option_type|
              option_type.presentation = name
              option_type.save!
            end

            unless product.option_types.include?(option_type)
              product.option_types << option_type
            end
          end
        end
      end
    end
  end
end
