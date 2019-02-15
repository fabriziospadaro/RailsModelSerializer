module ModelSerializer
  class Importer < Base

    def initialize(file_path:)
      raise "Unable to locate the file" unless File.file?(file_path)
      raise "Provide a json file" unless File.extname(file_path) == ".json"
      @file_path = file_path
    end


    def update_file_path(file_path:)
      raise "Unable to locate the file" unless File.file?(file_path)
      raise "Provide a json file" unless File.extname(file_path) == ".json"
      @file_path = file_path
    end

    def call
      json_data = JSON.parse(File.read(@file_path))
      klass_root = json_data.keys[0].singularize
      json_data[klass_root.pluralize].each do |data_hash|
        build_model(klass_root.classify.constantize, data_hash.to_json, klass_root.to_sym);
      end
    end

    private

    #extract only absolute properties skipping any id references
    def extract_properties(data)
      data.reject {|k, v| k.to_s.last(2) == "id" || ["created_at", "updated_at"].include?(k)}
    end

    def build_model(klass, data, dependency_sym = nil, father = nil)
      property_hash = JSON.parse(data)
      return unless property_hash
      klass_symbol = dependency_sym
      instance = klass.new
      instance.from_json(data) rescue instance
      cleaned_properties = extract_properties(JSON.parse(instance.to_json))
      #if we can find a model with the same exact properties let's just return the matching model
      return klass.where(cleaned_properties).first if klass.where(cleaned_properties).first
      #create the object using the latest id available
      instance.id = (klass.all.last.id rescue 0) + 1
      if (klass == User rescue false)
        begin
          instance.password = property_hash["encrypted_password"]
          instance.password_confirmation = property_hash["encrypted_password"]
          instance.confirmed_at = Time.now
        rescue
          raise "Cannot locate encrypted_password in the exported file, did you set encrypted_password in the augmentation table for user?"
        end
      end
      if dependency_of(klass_symbol)
        dependency_of(klass_symbol).each do |dependency|
          dependency_klass = dependency.to_s.classify.constantize
          old_value = instance.send(dependency)
          is_plural = dependency.to_s[-1] == "s"
          method = (dependency.to_s + "=").to_sym
          if dependency_klass == father.class
            instance.send(method, (is_plural ? old_value && [father] : father))
          else
            new_model = []
            [property_hash[dependency.to_s]].flatten.each do |model_info|
              new_model << build_model(dependency_klass, model_info.to_json, dependency, instance)
            end
            new_model.reject! {|model| model == nil}
            collection = dependency_klass.where(id: new_model.map(&:id))
            instance.send(method, (is_plural ? old_value && collection : collection[0]))
          end
        end
      end
      unless instance.valid?
        param = instance.errors.details.keys[0]
        value = instance.errors.details.first[1][0][:value]
        error = instance.errors.details.first[1][0][:error]
        return klass.where(param => value).first if (error == :taken)
      end
      instance.save
      return instance
    end
  end
end