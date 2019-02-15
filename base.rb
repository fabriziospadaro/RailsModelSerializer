module ModelSerializer
  class Base
    @dependency_table = {}
    #map all the dependencies through models
    def set_dependency(dependencies)
      raise "Provide a type: Hash" unless dependencies.class == Hash
      @dependency_table = dependencies
    end

    private

    def dependency_of(symbol)
      new_symbol = symbol.to_s[-1] == "s" ? symbol.to_s.singularize.to_sym : symbol.to_s.pluralize.to_sym
      if @dependency_table[symbol]
        @dependency_table[symbol]
      else
        @dependency_table[new_symbol]
      end
    end
  end
end