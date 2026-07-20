module Spree
  module Api
    module V3
      class ProductFilterCategoryOptionSerializer < BaseSerializer
        typelize id: :string,
                 name: :string,
                 permalink: :string,
                 count: :number

        attributes :id, :name, :permalink, :count
      end
    end
  end
end
