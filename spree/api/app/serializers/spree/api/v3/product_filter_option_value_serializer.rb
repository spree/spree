module Spree
  module Api
    module V3
      class ProductFilterOptionValueSerializer < BaseSerializer
        typelize id: :string,
                 name: :string,
                 label: :string,
                 position: :number,
                 color_code: [:string, nullable: true],
                 image_url: [:string, nullable: true],
                 count: :number

        attributes :id, :name, :label, :position, :color_code, :image_url, :count
      end
    end
  end
end
