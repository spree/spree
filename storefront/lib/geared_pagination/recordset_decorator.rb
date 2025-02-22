# TODO: Remove this file when this issue is resolved:
# https://github.com/basecamp/geared_pagination/issues/8
module GearedPagination
  module RecordsetDecorator
    def records_count
      return @records_count if defined?(@records_count)

      @records_count ||= records.unscope(:limit).unscope(:offset).unscope(:select).unscope(:order).unscope(:group).unscope(:includes).size
    end
  end

  Recordset.prepend(RecordsetDecorator)
end
