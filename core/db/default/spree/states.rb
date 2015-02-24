require 'carmen'
connection = ActiveRecord::Base.connection
state_inserts = []

state_values = -> do
  Spree::Country.where(states_required: true).each do |country|
    carmen_country = Carmen::Country.named(country.name)
    carmen_country.subregions.each do |subregion|
      name       = connection.quote subregion.name
      abbr       = connection.quote subregion.code
      country_id = connection.quote country.id
      if  connection.adapter_name =~ /SQLite/i 
        state_inserts << ["#{name} as 'name'", "#{abbr} as 'abbr'", "#{country_id} as 'country_id'"].join(", ")
      else
        state_inserts << [name, abbr, country_id].join(", ")
      end
    end
  end
  if connection.adapter_name =~ /SQLite/i
    state_inserts.map { |x| " #{x} " }
  else
    state_inserts.map { |x| "(#{x})" }
  end
  
end

columns = ["name", "abbr", "country_id"].map do |column|
  connection.quote_column_name column
end.join(', ')

state_values.call.each_slice(500) do |state_values_batch|
  if connection.adapter_name =~ /SQLite/i
    connection.execute <<-SQL
      INSERT INTO spree_states (#{columns})
      SELECT #{state_values_batch.join(" UNION SELECT ")};
    SQL
  else
    connection.execute <<-SQL
      INSERT INTO spree_states (#{columns})
      VALUES #{state_values_batch.join(", ")};
    SQL
  end
end