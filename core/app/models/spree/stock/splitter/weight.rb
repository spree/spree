module Spree
  module Stock
    module Splitter
      class Weight < Spree::Stock::Splitter::Base
        attr_reader :packer, :next_splitter

        cattr_accessor :threshold do
          150
        end

        def split(packages)
          packages.each do |package|
            removed_contents = reduce package
            packages << build_package(removed_contents) unless removed_contents.empty?
          end
          return_next packages
        end

        private
        def reduce(package)
          removed = []
          while package.weight > self.threshold
            contents = package.contents_by_weight
            break if contents.size == 1
            # Deleting the second heaviest item in the package should yield best results
            removed << package.contents.delete(contents[1])
          end
          removed
        end
      end
    end
  end
end

