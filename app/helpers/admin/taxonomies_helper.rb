module Admin::TaxonomiesHelper


   ## YUI stuff
   def yui_tree_helper(taxonomy)
     tree_elem_id = taxonomy.id
     cm_elem_id = "cm_#{taxonomy.id}"
     tree_data_name = "tree_data_#{taxonomy.id}"
     tree_data = build_tree_data(taxonomy)
     out = <<EOT
<div id="#{tree_elem_id}" class="taxonomy_tree"></div>
<script type="text/javascript">


  function setup_tree(){
//<![CDATA[
  var #{tree_data_name} = #{tree_data};
//]]>
  var tree = spree.YUI.build_tree("#{tree_elem_id}", #{tree_data_name});
  tree.tree_view.draw();
  spree.YUI.add_inplace_controls(#{tree_data_name});
};


YAHOO.util.Event.onDOMReady(setup_tree, spree.YUI.DDList, true);
</script>
EOT
     out
   end

   def build_tree_data(taxonomy)
     html = %Q{<span id=\\"node_#{taxonomy.root.id}\\" class=\\"spree-YUI-tree-node\\">}
     html << taxonomy.root.name
     html << %Q{</span>&nbsp;<img src='/images/spinner.gif' style='display:none;vertical-align:middle;' id='#{dom_id(taxonomy.root)}'>}
     
     out = [%Q{{"id":#{taxonomy.root.id}, "parent_id":null, "object_url":"#{admin_taxonomy_taxon_path(taxonomy, taxonomy.root)}", "html":"#{html}"}}]
     taxonomy.root.descendents.each do |node| 
       html = %Q{<span id=\\"node_#{node.id}\\" class=\\"spree-YUI-tree-node\\">}
       html << node.name
       html << %Q{</span>&nbsp;<img src='/images/spinner.gif' style='display:none;vertical-align:middle;' id='#{dom_id(node)}'>}
       out << [%Q{{"id":#{node.id}, "parent_id":#{node.parent.id}, "object_url":"#{admin_taxonomy_taxon_path(node.taxonomy, node)}","position": #{node.position}, "html":"#{html}"}}]
     end
     return %Q{[#{out.join(",\n")}]}
   end

  def yui_build_tree(node)
    out = yui_build_node(node)
    node.children.each do |child|
      out += yui_build_tree(child)
    end
    out
  end

  def yui_build_node(node)
    parent_node_name = node.root? ? 'tree.getRoot()' : "node_#{node.parent.id}"
    node_name = "node_#{node.id}"
    html = "#{node.presentation}"
    out = %Q{var #{node_name} = new YAHOO.widget.HTMLNode("#{html}", #{parent_node_name}, false, true);\n}
    out += %Q{nodeMap[#{node_name}.labelElId] = #{node_name};\n}
    out
  end
end
