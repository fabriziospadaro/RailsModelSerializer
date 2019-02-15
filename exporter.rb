module ModelSerializer
  class Exporter < Base
    def initialize(klass:)
      raise "Provide a type: Class" unless klass.class == Class
      @klass_root = klass
      @augmentation_table = {}
    end

    def update_class_root(klass)
      raise "Provide a type: Class" unless klass.class == Class
      @klass_root = klass
    end

    #map additional parameters not extracted by default using model.as_json:
    def set_augmentation(augmentation)
      raise "Provide a type: Hash" unless augmentation.class == Hash
      @augmentation_table = augmentation
    end

    def call(path:)
      data = {}
      pluralized_name = @klass_root.to_s.underscore.pluralize
      data[pluralized_name] = @klass_root.all.map {|model| model.as_json(build_dependencies(pluralized_name.singularize.to_sym))}
      File.open(path + "/#{pluralized_name}_export_#{DateTime.now.to_i}.json", "w") {|f| f.write(JSON.dump(data))}
    end

    private

    def build_dependencies(klass)
      final = []
      dependency_of(klass).each do |dependency|
        if dependency_of(dependency) && !dependency_of(dependency).include?(klass.to_s.singularize.to_sym) && !dependency_of(dependency).include?(klass.to_s.pluralize.to_sym)
          final << {dependency => build_dependencies(dependency)}
        else
          final << dependency
        end
      end
      return @augmentation_table[klass].nil? ? {include: final} : {include: final, methods: @augmentation_table[klass]}
    end
  end
end