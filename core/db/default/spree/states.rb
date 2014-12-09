connection = ActiveRecord::Base.connection
case connection.adapter_name
when "PostgreSQL"
  state_inserts = []

  state_values = -> do
    Spree::Country.all.each do |country|
      carmen_country = Carmen::Country.named(country.name)
      if carmen_country.subregions?
        carmen_country.subregions.each do |subregion|
          state_inserts << [subregion.name, subregion.code, country.id.to_s]
        end
      end
    end
    state_inserts.map do |state_insert|
      state_insert.map do |state_value|
        state_value.gsub("'", "''")
      end.join("', '")
    end.join("'), ('")
  end

  connection.execute <<-SQL
    INSERT INTO spree_states ("name", "abbr", "country_id")
    VALUES ('#{state_values.call}');
  SQL
else
  Spree::Country.all.each do |country|
    carmen_country = Carmen::Country.named(country.name)
    @states ||= []
    if carmen_country.subregions?
      carmen_country.subregions.each do |subregion|
        @states << {
          name: subregion.name,
          abbr: subregion.code,
          country: country
        }
      end
    end
  end
  Spree::State.create!(@states)
end
