require 'velocity/mapped_row'
require 'velocity/results/postgresql'

module Velocity
  class DataQueryMap
    def initialize(model_binding)
      begin
        @handler = "Velocity::#{model_binding.connection.adapter_name}Result".constantize
      rescue NameError
        raise "Velocity does not currently support the #{model_binding.connection.adapter_name} adapter.\n Head on over to http://github.com/pascalh1011/velocity to add an issue, or if you're feeling generous, submit an appropriate handler for your database adapter."
      end

      @model = model_binding
      @results = nil # For accepting last query (from Result)
      @fields = ""
      @conditions = []
      @orders = []
      @joins = []
     
      # Prepare and proxy methods pertaining to results onto the Result object (after performing the query)
      (@handler.instance_methods-@handler.superclass.instance_methods).each do |method|
        define_singleton_method(method) do |*arguments|
          prepare_and_run_query
          @results.send(method, *arguments)
        end
      end
      
    end
    
    def select(fields='')
      @fields = [@fields, fields].join(', ') unless fields.blank?
      self
    end
    
    def limit(limit=nil)
      @limit = limit.to_i
      self
    end
    
    def where(conditions={})
      @conditions << @model.send(:sanitize_sql_for_conditions, conditions) unless conditions.empty?
      self
    end
    
    def joins(list_of_associations=[])
      @joins += list_of_associations unless list_of_associations.empty?
      self
    end
    
    def order(field_and_direction='')
      @orders << field_and_direction unless field_and_direction.blank?
      self
    end
    
    def all
      limit(0)
      prepare_and_run_query
      @results
    end
    
    def first
      limit(1)
      prepare_and_run_query
      @results.first
    end 
    
    private
    def prepare_and_run_query
      unless @joins.blank?
        @joins = @joins.collect do |association|
          association_reflection = @model.reflect_on_association(association)
          "LEFT JOIN #{association_reflection.table_name} ON #{@model.table_name}.#{association_reflection.association_foreign_key} = #{association_reflection.table_name}.#{association_reflection.klass.primary_key_name}"
        end.join
      end
      @fields = "#{@model.table_name}.*" if @fields.blank?
      @limit = (@limit.to_i > 0)? "LIMIT #{@limit}" : ""
      @conditions = "WHERE #{@conditions.join(' AND ')}" unless @conditions.blank?
              
      sql = "SELECT #{@fields} FROM #{@model.table_name} "+[@joins, @conditions, @limit].reject(&:blank?).join(' ')
      @results = @handler.new(sql, @model.connection)
    end
  end
end
