module Spree
  class ProductScope < ActiveRecord::Base
    before_validation(:on => :create) do
      # Add default empty arguments so scope validates and errors aren't caused when previewing it
      if name && args = self.class.arguments_for_scope_name(name)
        self.arguments ||= ['']*args.length
      end
    end

    def self.all_scopes
      {
        # Scopes for selecting products based on taxon
        :taxon => {
          :taxons_name_eq => [:taxon_name],
          :in_taxons => [:taxon_names],
        },
        # product selection based on name, or search
        :search => {
          :in_name => [:words],
          :in_name_or_keywords => [:words],
          :in_name_or_description => [:words],
          :with_ids => [:ids]
        },
        # Scopes for selecting products based on option types and properties
        :values => {
          :with => [:value],
          :with_property => [:property],
          :with_property_value => [:property, :value],
          :with_option => [:option],
          :with_option_value => [:option, :value],
        },
        # product selection based upon master price
        :price => {
          :price_between => [:low, :high],
          :master_price_lte => [:amount],
          :master_price_gte => [:amount],
        },
      }
    end

    def self.arguments_for_scope_name(name)
      if group = all_scopes.detect { |k,v| v[name.to_sym] }
        group[1][name.to_sym]
      end
    end
  end
end
