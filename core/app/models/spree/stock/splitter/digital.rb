module Spree
  module Stock
    module Splitter
      class Digital < Base
        def split(packages)
          split_packages = []
          packages.each do |package|
            split_packages += split_by_digital(package)
          end
          return_next split_packages
        end

        private

        def split_by_digital(package)
          digitals = Hash.new { |hash, key| hash[key] = [] }
          package.contents.each do |item|
            digitals[item.variant.digital?] << item
          end
          hash_to_packages(digitals)
        end

        def hash_to_packages(digitals)
          packages = []
          digitals.each do |_id, contents|
            packages << build_package(contents)
          end
          packages
        end
      end
    end
  end
end
