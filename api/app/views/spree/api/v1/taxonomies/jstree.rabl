object false
node(:data) { @taxonomy.root.name }
node(:attr) do
  { :id => @taxonomy.root.id,
    :name => @taxonomy.root.name
  }
end
node(:state) { "closed" }
