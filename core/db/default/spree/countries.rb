require 'carmen'
connection      = ActiveRecord::Base.connection
country_inserts = []

country_values = -> do
  Carmen::Country.all.each_with_index do |country, index|
    name            = connection.quote country.name
    iso3            = connection.quote country.alpha_3_code
    iso             = connection.quote country.alpha_2_code
    iso_name        = connection.quote country.name.upcase
    numcode         = connection.quote country.numeric_code
    states_required = connection.quote country.subregions?
    if index == 0 && connection.adapter_name =~ /SQLite/i
      country_inserts << ["#{name} as 'name'", \
                          "#{iso3} as 'iso3'", \
                          "#{iso} as 'iso'", \
                          "#{iso_name} as 'iso_name'", \
                          "#{numcode} as 'numcode'", \
                          "#{states_required} as 'states_required'"].join(', ')
    else
      country_inserts << [name, iso3, iso, iso_name, numcode, states_required].join(', ')
    end
  end
  if connection.adapter_name =~ /SQLite/i
    "SELECT #{country_inserts.join(' UNION SELECT ')} "
  else
    country_inserts.join("), (")
  end
end

columns = ["name", "iso3", "iso", "iso_name", "numcode", "states_required"]
columns = connection.adapter_name =~ /MySQL/i ? columns.join(", ") : "\"#{columns.join('", "')}\""

if connection.adapter_name =~ /SQLite/i
  connection.execute <<-SQL
    INSERT INTO spree_countries (#{columns})
    #{country_values.call};
  SQL
else
  connection.execute <<-SQL
    INSERT INTO spree_countries (#{columns})
    VALUES (#{country_values.call});
  SQL
end

Spree::Config[:default_country_id] = Spree::Country.find_by(name: "United States").id
