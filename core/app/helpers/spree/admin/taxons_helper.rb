module Spree
  module Admin
    module TaxonsHelper
      def taxon_path(taxon)
        taxon.ancestors.reverse.collect { |ancestor| ancestor.name }.join( " >> ")
      end
  
      def taxons_checkbox_tree(root, product)
        return '' if root.children.blank?
        content_tag 'ul' do
          root.children.map do |taxon|
            content_tag 'li' do
              [check_box_tag("taxon_ids[]", taxon.id, product.taxons.include?(taxon), :id => "taxon_ids_#{taxon.id}"),
               label_tag("taxon_ids_#{taxon.id}", taxon.name)].join('&nbsp;').html_safe +
              taxons_checkbox_tree(taxon, product)
            end.html_safe
          end.join("\n").html_safe
        end
      end
    end
  end
end
