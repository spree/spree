module Spree
  module Stock
    module Splitter
      class Weight < Spree::Stock::Splitter::Base
        attr_reader :packer, :next_splitter

        cattr_accessor :threshold do
          150
        end

        def split(packages)
          generated_packages = []
          packages.each do |package|
            generated_packages.push *reduce(package)
          end
          packages.push *generated_packages
          return_next packages
        end

        private
        def reduce(package)
          package.split_contents_over_weight self.threshold
          contents = package.contents_by_weight
          # Treat current package as one of the generated packages for convenience and add the heaviest item
          # This also prevents an additional package if no fit is possible
          package.contents.clear
          package.contents << contents.shift
          generated = [package]
          while contents.present?

            package_to_use = choose_package generated, contents.first

            if package_to_use.nil?
              package_to_use = build_package
              generated << package_to_use
            end

            package_to_use.contents << contents.shift
          end

          generated.drop 1 # Drop the original package to ensure only generated packages are returned
        end

        def choose_package(generated_packages, content_to_add)
          # Implements worst fit
          # See: http://www.labri.fr/perso/eyraud/pmwiki/uploads/Main/BinPackingSurvey.pdf, for survey of other techniques
          package_to_use     = nil
          available_space    = -1

          generated_packages.each do |generated_package|
            generated_package_weight = generated_package.weight
            if ((generated_package_weight + content_to_add.weight <= self.threshold) &&
                (available_space < self.threshold - generated_package_weight))
              package_to_use = generated_package
              available_space = self.threshold - generated_package_weight
            end
          end

          package_to_use
        end
      end
    end
  end
end
