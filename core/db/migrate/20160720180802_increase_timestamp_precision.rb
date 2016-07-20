class IncreaseTimestampPrecision < ActiveRecord::Migration
  def change
    ActiveRecord::Base.connection.tables.each do |table_name|
      columns = ActiveRecord::Base.connection.columns(table_name)

      # set the precision to microseconds for each datetime column on the table
      columns.select { |col| col.type == :datetime }.each do |column|
        change_column table_name, column.name, :datetime, limit: 6
      end
    end
  end
end
