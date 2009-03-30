module Searchlogic
  module ActiveRecord
    module ConnectionAdapters
      module PostgreSQLAdapter
        # Datetime functions
        def microseconds_sql(column_name)
          "date_part('microseconds', #{column_name})"
        end
        
        def milliseconds_sql(column_name)
          "date_part('milliseconds', #{column_name})"
        end
        
        def second_sql(column_name)
          "date_part('second', #{column_name})"
        end
        
        def minute_sql(column_name)
          "date_part('minute', #{column_name})"
        end
        
        def hour_sql(column_name)
          "date_part('hour', #{column_name})"
        end
        
        def day_of_week_sql(column_name)
          "(date_part('dow', #{column_name}) + 1)"
        end
        
        def day_of_month_sql(column_name)
          "date_part('day', #{column_name})"
        end
        
        def day_of_year_sql(column_name)
          "date_part('doy', #{column_name})"
        end
        
        def week_sql(column_name)
          "date_part('week', #{column_name})"
        end
        
        def month_sql(column_name)
          "date_part('month', #{column_name})"
        end
        
        def year_sql(column_name)
          "date_part('year', #{column_name})"
        end
        
        # String functions
        def char_length_sql(column_name)
          "length(#{column_name})"
        end
        
        def lower_sql(column_name)
          "lower(#{column_name})"
        end
        
        def ltrim_sql(column_name)
          "ltrim(#{column_name})"
        end
        
        def md5_sql(column_name)
          "md5(#{column_name})"
        end
        
        def rtrim_sql(column_name)
          "rtrim(#{column_name})"
        end
        
        def trim_sql(column_name)
          "trim(#{column_name})"
        end
        
        def upper_sql(column_name)
          "upper(#{column_name})"
        end
        
        # Number functions
        def absolute_sql(column_name)
          "abs(#{column_name})"
        end
        
        def acos_sql(column_name)
          "acos(#{column_name})"
        end
        
        def asin_sql(column_name)
          "asin(#{column_name})"
        end
        
        def atan_sql(column_name)
          "atan(#{column_name})"
        end
        
        def avg_sql(column_name)
          "AVG(#{column_name})"
        end
        
        def ceil_sql(column_name)
          "ceil(#{column_name})"
        end
        
        def cos_sql(column_name)
          "cos(#{column_name})"
        end
        
        def cot_sql(column_name)
          "cot(#{column_name})"
        end
        
        def degrees_sql(column_name)
          "degrees(#{column_name})"
        end
        
        def exp_sql(column_name)
          "exp(#{column_name})"
        end
        
        def floor_sql(column_name)
          "floor(#{column_name})"
        end
        
        def hex_sql(column_name)
          "to_hex(#{column_name})"
        end
        
        def ln_sql(column_name)
          "ln(#{column_name})"
        end
        
        def log_sql(column_name)
          "log(#{column_name})"
        end
        
        def log2_sql(column_name)
          "log(2.0, #{column_name})"
        end
        
        def log10_sql(column_name)
          "log(10.0, #{column_name})"
        end
        
        def radians_sql(column_name)
          "radians(#{column_name})"
        end
        
        def round_sql(column_name)
          "round(#{column_name})"
        end
        
        def sign_sql(column_name)
          "sign(#{column_name})"
        end
        
        def sin_sql(column_name)
          "sin(#{column_name})"
        end
        
        def square_root_sql(column_name)
          "sqrt(#{column_name})"
        end
        
        def tan_sql(column_name)
          "tan(#{column_name})"
        end
      end
    end
  end
end

::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send(:include, Searchlogic::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)