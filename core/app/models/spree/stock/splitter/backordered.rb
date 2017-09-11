module Spree
  module Stock
    module Splitter
      class Backordered < Spree::Stock::Splitter::Base
        def split(packages)
          split_packages = []
          packages.each do |package|
            unless package.on_hand.empty?
              split_packages << build_package(package.on_hand)
            end

            unless package.backordered.empty?
              split_packages << build_package(package.backordered)
            end
          end
          return_next split_packages
        end
      end
    end
  end
end
