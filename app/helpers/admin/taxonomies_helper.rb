module Admin::TaxonomiesHelper
  def tree_editor(root)
    out = %Q{<ul class="tree" id="spree-tree">\n}
    out << show_tree(root, {:visible => [:new, :delete, :move, :products], :move => [:finalize, :cancel]})
    out << "</ul>\n"
    out
  end

  def show_node(node, actions = {})
    out = %Q{<li class='tree-node' id="tree-node-#{node.id}">}
    initial_class = 'tree-drop-node tree-nav-leaf'
    if ! node.children.empty?
      initial_class = 'tree-drop-node tree-nav-open'
    end

    out << %Q{ <span class="#{initial_class}" id="tree-node-name-#{node.id}">#{node.name}</span> }

    ## visible actions
    if ! actions[:visible].empty?
      out << %Q{<span class="tree-node-options" id="tree-node-options-#{node.id}">}
      out << actions[:visible].collect { |a| show_action(a, node) }.compact().join(" | ")
      out << "</span>"
    end
    
    ## move actions (initially hidden)
    if ! actions[:move].empty?
      out << %Q{<span style="display:none" class="tree-node-move-options" id="tree-node-move-options-#{node.id}">}
      out << actions[:move].collect { |a| show_action("move_#{a.to_s}".to_sym, node) }.compact().join(" | ")
      out << "</span>"
    end
    out << "\n"
    out
  end

  def show_tree(node, actions = {})
    out = show_node(node, actions)
#    if ! node.children.empty?
      out << %Q{<ul id="#{branch_id(node)}">\n}
      node.children.each do |child|
        out << show_tree(child, actions)
      end
      out << "</ul>\n"
#    end
    out << "</li>\n"
    out
  end

  def branch_id(node)
    "tree-branch-#{node.id}"
  end

  def show_action(a, node)
    method("show_action_#{a.to_s}").call(node)
  end

  def show_action_new(node)
    link_to_remote "New", :url => { :action => :new_taxon, 
                                    'new_taxon[parent_id]' => node,
                                    'new_taxon[taxonomy_id]' => node.taxonomy_id }, 
                          :update => 'new-taxon'
  end

  def show_action_delete(node)
    link_to_remote "Delete", :url => { :action => :delete_taxon, :id => node },
                             :update => 'edit-taxonomy',
                             :confirm => 'Are you sure that you want to delete this taxon?'
  end
  
  def show_action_products(node)
    link_to_remote "Products", :url => { :action => :manage_products, :id => node },
                               :update => 'manage-products'
  end

  def show_action_move(node)
    return nil if node.root?

    onclick = "spree.tree.move(#{node.id})"
    %Q{<a href="#" onClick="#{onclick}">Move</a>}
  end

  def show_action_move_cancel(node)
    onclick = "spree.tree.cancel_move(#{node.id})"
    %Q{<a href="#" onClick="#{onclick}">Cancel</a>}
  end

  def show_action_move_finalize(node)
    onclick = "spree.tree.save_move(#{node.id})"
    %Q{<a href="#" onClick="#{onclick}">Save</a>}
  end

  def cancel_button(label, div_id, show=nil, hide=nil)
    onclick =  %Q{Element.update('#{div_id}','');}
    onclick += %Q{Element.show('#{show}');} if show
    onclick += %Q{Element.hide('#{hide}');} if hide

    %Q{<button type="reset" onClick="#{onclick}">#{label}</button>}
  end

  def save_button(label, div_id, id)
    remote_options = {:update => div_id, :url => {:action => 'save_products', :id => id}}
    button_to_function(label, "spree.taxon.pm.save_products('#{div_id}', #{id})")
  end

  def reload_button(label, div_id, action, id)
    remote_options = {:update => div_id, :url => {:action => action, :id => id}}
    button_to_function(label, remote_function(remote_options))
#    %Q{<button type="reset">#{label}t</button>}
  end


  ## YUI stuff
   def yui_tree_helper(taxonomy)
     tree_elem_id = taxonomy.id
     cm_elem_id = "cm_#{taxonomy.id}"
     tree_data_name = "tree_data_#{taxonomy.id}"
     tree_data = build_tree_data(taxonomy)
     out = <<EOT
<div id="#{tree_elem_id}" class="taxonomy_tree"></div>
<script type="text/javascript">
//<![CDATA[
  var #{tree_data_name} = #{tree_data};
//]]>
  var tree = spree.YUI.build_tree("#{tree_elem_id}", #{tree_data_name});
  tree.tree_view.draw();
  
</script>
EOT
     out
   end

   def build_tree_data(taxonomy)
     html = %Q{<span id=\\"#{taxonomy.root.id}\\" class=\\"spree-YUI-tree-node\\" onmouseover=\\"style.backgroundColor='#E7EDF1';\\" onmouseout=\\"style.backgroundColor='#fff'\\">#{taxonomy.root.presentation}&nbsp;<img src='/images/spinner.gif' style='display:none;vertical-align:middle;' id='#{dom_id(taxonomy.root)}'></span>}
     out = [%Q{{"id":#{taxonomy.root.id}, "parent_id":null, "object_url":"#{admin_taxonomy_taxon_path(taxonomy, taxonomy.root)}", "html":"#{html}"}}]
     taxonomy.root.descendents.each do |node| 
       logger.debug("NODE #{node}")
       html = %Q{<span id=\\"#{node.id}\\" class=\\"spree-YUI-tree-node\\" onmouseover=\\"style.backgroundColor='#E7EDF1';\\" onmouseout=\\"style.backgroundColor='#fff'\\">#{node.presentation}&nbsp;<img src='/images/spinner.gif' style='display:none;vertical-align:middle;' id='#{dom_id(node)}'></span>}
       out << [%Q{{"id":#{node.id}, "parent_id":#{node.parent.id}, "object_url":"#{admin_taxonomy_taxon_path(node.taxonomy, node)}", "html":"#{html}"}}]
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
