module Spree
  module Admin
    module TaxonsHelper
      def taxon_path(taxon)
        taxon.ancestors.reverse.collect { |ancestor| ancestor.name }.join( " >> ")
      end

      def taxon_picker_collection taxon_ids
        # returns an array with values for the taxon picker collection
        # sorted by name

        taxon_ids.collect do |id, index|
          taxon = Spree::Taxon.find(id)
          Hashie::Mash.new(id: taxon.id, name: taxon.name, pretty_name: taxon.pretty_name)
        end.sort { |a,b| a.name <=> b.name }
      end
    end
  end
end
