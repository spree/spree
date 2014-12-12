connection = ActiveRecord::Base.connection
state_inserts = []

state_values = -> do
  Spree::Country.where(states_required: true).each do |country|
    carmen_country = Carmen::Country.named(country.name)
    carmen_country.subregions.each do |subregion|
      name       = connection.quote subregion.name
      abbr       = connection.quote subregion.code
      country_id = connection.quote country.id

      state_inserts << [name, abbr, country_id].join(", ")
    end
  end

  state_inserts.map { |x| "(#{x})" }
end

columns = ["name", "abbr", "country_id"].map do |column|
  connection.quote_column_name column
end.join(', ')

state_values.call.each_slice(500) do |state_values_batch|
  connection.execute <<-SQL
    INSERT INTO spree_states (#{columns})
    VALUES #{state_values_batch.join(", ")};
  SQL
end
