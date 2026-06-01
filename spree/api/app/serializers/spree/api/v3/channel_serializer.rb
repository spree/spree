module Spree
  module Api
    module V3
      class ChannelSerializer < BaseSerializer
        typelize name: :string,
                 code: :string,
                 active: :boolean,
                 default: :boolean

        attributes :name, :code, :active, :default
      end
    end
  end
end
