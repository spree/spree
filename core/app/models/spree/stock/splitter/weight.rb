module Spree
  module Stock
    module Splitter
      class Weight < Spree::Stock::Splitter::Base
        attr_reader :packer, :next_splitter

        cattr_accessor(:threshold) { 150 }

        def split(packages)
          generated_packages = packages.flat_map(&method(:reduce))
          packages.push(*generated_packages)
          return_next(packages)
        end

        private

        def reduce(package)
          contents = split_package_contents_over_threshold(package).sort { |x, y| y.weight <=> x.weight }
          # Treat current package as one of the generated packages for convenience and add the heaviest item
          # This also prevents an additional package if no fit is possible
          package.contents.clear
          package.contents << contents.shift
          split_packages = [package]

          while contents.present?
            package_to_use = choose_package(split_packages, contents.first)

            if package_to_use.nil?
              package_to_use = build_package
              split_packages << package_to_use
            end

            package_to_use.contents << contents.shift
          end

          split_packages.drop(1)
        end

        def choose_package(generated_packages, content_to_add)
          # Implements worst fit, add to package with most space left over after addition.
          # See: http://www.labri.fr/perso/eyraud/pmwiki/uploads/Main/BinPackingSurvey.pdf,
          # for survey of other techniques
          package_to_use     = nil
          available_space    = -1

          generated_packages.each do |generated_package|
            generated_package_weight = generated_package.weight

            weight_exceed = (generated_package_weight + content_to_add.weight) > threshold
            space_left = available_space >= (threshold - generated_package_weight)

            next if weight_exceed || space_left

            package_to_use = generated_package
            available_space = threshold - generated_package_weight
          end

          package_to_use
        end

        def split_package_contents_over_threshold(package)
          package.contents.flat_map do |content|
            if content.weight > threshold && content.splittable_by_weight?
              split_content_item_over_threshold(content)
            else
              content
            end
          end
        end

        def split_content_item_over_threshold(content_item)
          per_content_max_quantity = (threshold / content_item.variant_weight).floor
          per_content_max_quantity = 1 if per_content_max_quantity.zero?
          content_items = [content_item]
          while content_item.quantity > per_content_max_quantity
            split_inventory = InventoryUnit.split(content_item.inventory_unit, per_content_max_quantity)
            content_items << ContentItem.new(split_inventory, content_item.state)
          end
          content_items
        end
      end
    end
  end
end
