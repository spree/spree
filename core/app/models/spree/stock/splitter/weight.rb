module Spree
  module Stock
    module Splitter
      class Weight < Base
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
            break if package.contents.size == 1
            removed << package.contents.shift
          end
          removed
        end
      end
    end
  end
end

