
class Cassandra
  # Inner methods for actually doing the Thrift calls
  module Protocol #:nodoc:
    private

    def _mutate(mutation, consistency)
      @client.batch_mutate(@keyspace, mutation, consistency)
    end

    def _count_columns(column_family, key, super_column, consistency)
      @client.get_count(@keyspace, key,
        CassandraThrift::ColumnParent.new(:column_family => column_family, :super_column => super_column),
        consistency
      )
    end

    def _get_columns(column_family, key, columns, sub_columns, consistency)
      result = if is_super(column_family)
        if sub_columns
          columns_to_hash(column_family, @client.get_slice(@keyspace, key,
            CassandraThrift::ColumnParent.new(:column_family => column_family, :super_column => columns),
            CassandraThrift::SlicePredicate.new(:column_names => sub_columns),
            consistency))
        else
          columns_to_hash(column_family, @client.get_slice(@keyspace, key,
            CassandraThrift::ColumnParent.new(:column_family => column_family),
            CassandraThrift::SlicePredicate.new(:column_names => columns),
            consistency))
        end
      else
        columns_to_hash(column_family, @client.get_slice(@keyspace, key,
          CassandraThrift::ColumnParent.new(:column_family => column_family),
          CassandraThrift::SlicePredicate.new(:column_names => columns),
          consistency))
      end
      sub_columns || columns.map { |name| result[name] }
    end

    def _get(column_family, key, column, sub_column, count, start, finish, reversed, consistency)
      # Single values; count and range parameters have no effect
      if is_super(column_family) and sub_column
        column_path = CassandraThrift::ColumnPath.new(:column_family => column_family, :super_column => column, :column => sub_column)
        @client.get(@keyspace, key, column_path, consistency).column.value
      elsif !is_super(column_family) and column
        column_path = CassandraThrift::ColumnPath.new(:column_family => column_family, :column => column)
        @client.get(@keyspace, key, column_path, consistency).column.value

      # Slices
      else
        predicate = CassandraThrift::SlicePredicate.new(:slice_range => 
          CassandraThrift::SliceRange.new(
            :reversed => reversed, 
            :count => count, 
            :start => start, 
            :finish => finish))
        
        if is_super(column_family) and column
          column_parent = CassandraThrift::ColumnParent.new(:column_family => column_family, :super_column => column)
          sub_columns_to_hash(column_family, @client.get_slice(@keyspace, key, column_parent, predicate, consistency))
        else
          column_parent = CassandraThrift::ColumnParent.new(:column_family => column_family)
          columns_to_hash(column_family, @client.get_slice(@keyspace, key, column_parent, predicate, consistency))
        end
      end
    end

    def _get_range(column_family, start, finish, count, consistency)
      # FIXME Consistency is ignored
      @client.get_key_range(@keyspace, column_family, start, finish, count)
    end
  end
end