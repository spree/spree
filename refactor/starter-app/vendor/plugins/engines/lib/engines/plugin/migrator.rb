# The Plugin::Migrator class contains the logic to run migrations from
# within plugin directories. The directory in which a plugin's migrations
# should be is determined by the Plugin#migration_directory method.
#
# To migrate a plugin, you can simple call the migrate method (Plugin#migrate)
# with the version number that plugin should be at. The plugin's migrations
# will then be used to migrate up (or down) to the given version.
#
# For more information, see Engines::RailsExtensions::Migrations
class Engines::Plugin::Migrator < ActiveRecord::Migrator

  # We need to be able to set the 'current' engine being migrated.
  cattr_accessor :current_plugin

  # Runs the migrations from a plugin, up (or down) to the version given
  def self.migrate_plugin(plugin, version)
    self.current_plugin = plugin
    migrate(plugin.migration_directory, version)
  end
  
  # Returns the name of the table used to store schema information about
  # installed plugins.
  #
  # See Engines.schema_info_table for more details.
  def self.schema_info_table_name
    ActiveRecord::Base.wrapped_table_name Engines.schema_info_table
  end

  # Returns the current version of the given plugin
  def self.current_version(plugin=current_plugin)
    result = ActiveRecord::Base.connection.select_one(<<-ESQL
      SELECT version FROM #{schema_info_table_name} 
      WHERE plugin_name = '#{plugin.name}'
    ESQL
    )
    if result
      result["version"].to_i
    else
      # There probably isn't an entry for this engine in the migration info table.
      # We need to create that entry, and set the version to 0
      ActiveRecord::Base.connection.execute(<<-ESQL
        INSERT INTO #{schema_info_table_name} (version, plugin_name) 
        VALUES (0,'#{plugin.name}')
      ESQL
      )      
      0
    end
  end

  # Sets the version of the plugin in Engines::Plugin::Migrator.current_plugin to
  # the given version.
  def set_schema_version(version)
    ActiveRecord::Base.connection.update(<<-ESQL
      UPDATE #{self.class.schema_info_table_name} 
      SET version = #{down? ? version.to_i - 1 : version.to_i} 
      WHERE plugin_name = '#{self.current_plugin.name}'
    ESQL
    )
  end
end
