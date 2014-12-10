connection = ActiveRecord::Base.connection
state_inserts = []

state_values = -> do
  Spree::Country.all.each do |country|
    carmen_country = Carmen::Country.named(country.name)
    if carmen_country.subregions?
      carmen_country.subregions.each do |subregion|
        name       = connection.quote subregion.name
        abbr       = connection.quote subregion.code
        country_id = connection.quote country.id

        state_inserts << [name, abbr, country_id].join(", ")
      end
    end
  end
  state_inserts.join("), (")
end

columns = ["name", "abbr", "country_id"]
columns = connection.adapter_name =~ /MySQL/i ? columns.join(", ") : "\"#{columns.join('", "')}\""

connection.execute <<-SQL
  INSERT INTO spree_states (#{columns})
  VALUES (#{state_values.call});
SQL
