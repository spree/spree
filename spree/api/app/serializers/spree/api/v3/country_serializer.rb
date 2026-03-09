module Spree
  module Api
    module V3
      class CountrySerializer
        include Alba::Resource
        include Typelizer::DSL

        typelize iso: :string, iso3: :string, name: :string,
                 states_required: :boolean, zipcode_required: :boolean,
                 market: [:Market, nullable: true]

        attributes :iso, :iso3, :name, :states_required, :zipcode_required

        many :states,
             resource: Spree.api.state_serializer,
             if: proc { params[:expand]&.include?('states') }

        attribute :market, if: proc { params[:expand]&.include?('market') } do |country|
          m = country.current_market
          m ? Spree.api.market_serializer.new(m, params: params).to_h : nil
        end
      end
    end
  end
end
