# frozen_string_literal: true
require 'pluck_all/version'
require 'active_record'
begin
  require 'mongoid'
  require 'pluck_all/mongoid_pluck_all'
rescue LoadError, Gem::LoadError

end

class ActiveRecord::Base
  if !defined?(attribute_types) && defined?(column_types)
    class << self
      # column_types was changed to attribute_types in Rails 5
      alias_method :attribute_types, :column_types
    end
  end
end

module ActiveRecord
  [
    *([Type::Value, Type::Integer, Type::Serialized] if defined?(Type::Value)),
    *([Enum::EnumType] if defined?(Enum::EnumType)),
  ].each do |s|
    s.class_eval do
      if !method_defined?(:deserialize) && method_defined?(:type_cast_from_database)
        # column_types was changed to attribute_types in Rails 5
        alias deserialize type_cast_from_database
      end
    end
  end
end

class ActiveRecord::Relation
  if Gem::Version.new(ActiveRecord::VERSION::STRING) < Gem::Version.new('4.0.0')
    def pluck_all(*args)
      result = select_all(*args)
      result.map! do |attributes| # This map! behaves different to array#map!
        initialized_attributes = klass.initialize_attributes(attributes)
        attributes.each do |key, attribute|
          attributes[key] = klass.type_cast_attribute(key, initialized_attributes) #TODO 現在AS過後的type cast會有一點問題
        end
        cast_carrier_wave_uploader_url(attributes)
      end
    end
  else
    def pluck_all(*args)
      result = select_all(*args)
      attribute_types = klass.attribute_types
      result.map! do |attributes| # This map! behaves different to array#map!
        attributes.each do |key, attribute|
          attributes[key] = result.send(:column_type, key, attribute_types).deserialize(attribute) #TODO 現在AS過後的type cast會有一點問題，但似乎原生的pluck也有此問題
        end
        cast_carrier_wave_uploader_url(attributes)
      end
    end
  end

  def cast_need_columns(column_names, _klass = nil)
    @pluck_all_cast_need_columns = column_names.map(&:to_s)
    @pluck_all_cast_klass = _klass
    return self
  end

  private

  def select_all(*args)
    args.map! do |column_name|
      if column_name.is_a?(Symbol) && column_names.include?(column_name.to_s)
        "#{connection.quote_table_name(table_name)}.#{connection.quote_column_name(column_name)}"
      else
        column_name.to_s
      end
    end
    relation = clone
    return klass.connection.select_all(relation.select(args).to_sql)
    #return klass.connection.select_all(relation.arel)
  end

  # ----------------------------------------------------------------
  # ● Support casting CarrierWave url
  # ----------------------------------------------------------------
  def cast_carrier_wave_uploader_url(attributes)
    if defined?(CarrierWave) && klass.respond_to?(:uploaders)
      @pluck_all_cast_klass ||= klass
      @pluck_all_uploaders ||= @pluck_all_cast_klass.uploaders.select{|key, uploader| attributes.key?(key.to_s) }
      @pluck_all_uploaders.each do |key, uploader|
        hash = {}
        @pluck_all_cast_need_columns.each{|k| hash[k] = attributes[k] } if @pluck_all_cast_need_columns
        obj = @pluck_all_cast_klass.new(hash)
        obj[key] = attributes[key_s = key.to_s]
        #https://github.com/carrierwaveuploader/carrierwave/blob/87c37b706c560de6d01816f9ebaa15ce1c51ed58/lib/carrierwave/mount.rb#L142
        attributes[key_s] = obj.send(key)
      end
    end
    return attributes
  end
end

class ActiveRecord::Relation
  if Gem::Version.new(ActiveRecord::VERSION::STRING) < Gem::Version.new('4.0.2')
    def pluck_array(*args)
      return pluck_all(*args).map{|hash|
        result = hash.values #P.S. 這裡是相信ruby 1.9以後，hash.values的順序跟insert的順序一樣。
        next (result.one? ? result.first : result)
      }
    end
  else
    alias_method :pluck_array, :pluck if not method_defined?(:pluck_array)
  end
end


class << ActiveRecord::Base
  def cast_need_columns(*args)
    where(nil).cast_need_columns(*args)
  end

  def pluck_all(*args)
    where(nil).pluck_all(*args)
  end

  def pluck_array(*args)
    where(nil).pluck_array(*args)
  end
end

module ActiveRecord::NullRelation
  def pluck_all(*args)
    []
  end
end
