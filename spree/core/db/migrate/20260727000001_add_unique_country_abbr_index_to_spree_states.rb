class AddUniqueCountryAbbrIndexToSpreeStates < ActiveRecord::Migration[7.2]
  def up
    remove_duplicate_states!

    add_index :spree_states, [:country_id, :abbr],
              unique: true,
              name: 'index_spree_states_on_country_id_and_abbr'
  end

  def down
    remove_index :spree_states, name: 'index_spree_states_on_country_id_and_abbr'
  end

  private

  # `Spree::Seeds::States` used a plain `insert_all` for province-level
  # countries, so re-running the seeds duplicated their states. Keep the oldest
  # row of each group — addresses point at it — and drop the rest.
  #
  # Reads the tables directly rather than through Spree::State and
  # Spree::Address: countries and states stopped being ActiveRecord models in
  # 6.0, and a migration has to keep working against the schema of its own day.
  def remove_duplicate_states!
    duplicated = select_rows(<<~SQL.squish)
      SELECT country_id, abbr FROM spree_states
      GROUP BY country_id, abbr HAVING COUNT(*) > 1
    SQL

    duplicated.each do |country_id, abbr|
      ids = select_values(
        "SELECT id FROM spree_states WHERE country_id = #{quote(country_id)} AND abbr = #{quote(abbr)} ORDER BY id"
      )
      keeper = ids.shift
      next if ids.empty?

      id_list = ids.map { |id| quote(id) }.join(', ')
      execute "UPDATE spree_addresses SET state_id = #{quote(keeper)} WHERE state_id IN (#{id_list})"
      execute "DELETE FROM spree_states WHERE id IN (#{id_list})"
    end
  end

  def quote(value)
    connection.quote(value)
  end

  def select_rows(sql)
    connection.select_rows(sql)
  end

  def select_values(sql)
    connection.select_values(sql)
  end
end
