module Spree
  module Stock
    module Splitter
      class Backordered < Spree::Stock::Splitter::Base

        def split(packages)
          split_packages = []
          packages.each do |package|
            if package.on_hand.size > 0
              split_packages << build_package(package.on_hand)
            end

            if package.backordered.size > 0
              split_packages << build_package(package.backordered)
            end
          end
          return_next split_packages
        end

      end
    end
  end
end
