require 'digest/md5'
require 'dag'

module JSON2Ruby
  # Entity represents a JSON Object.
  class Entity
    # The String name of the Object - i.e. the field name in which it was first encountered. 
    attr_accessor :name
    # The original String name of the object in the JSON ([^A-Za-z0-9_] are replaced with '_')
    attr_accessor :original_name
    # A Hash of String names to Attribute instances for this Entity, representing its attributes.
    attr_accessor :attributes

    # The short name is 'Entity'
    def self.short_name
      "Entity"
    end

    def self.dag
      @@DAG ||= DAG.new
    end

    # Create a new Entity with the specified name and optional Hash of attributes (String name to Entity, Collection or Primitive instances)
    def initialize(name, attributes = {})
      @name = name
      @attributes = attributes

    end

    # Return a 128-bit hash as a hex string, representative of the unique set of fields and their types, including all subobjects.
    # Internally, this is calculated as the MD5 of all field names and their type attr_hash calls.
    def attr_hash
      md5 = Digest::MD5.new
      # just hash it by name
      md5.update @name

      # @attributes.each do |k,v|
      #   md5.update "#{k}:#{v.attr_hash}"
      # end
      md5.hexdigest
    end

    # Compare this Entity with another. An entity is equal to another entity if and only if it has:
    # * The same number of fields
    # * The fields have the same case-sensitive name
    # * The fields have the same types, as tested with `attr_hash`
    # i.e. in short, an entity is equal to another entity if and only if both +attr_hash+ calls return the same value.
    def ==(other)
      return false if other.class != self.class
      attr_hash == other.attr_hash
    end

    # Reset the internal type cache for all Entities everywhere, and reset the global Unknown number.
    def self.reset_parse
      @@objs = {
        RUBYSTRING.attr_hash => RUBYSTRING,
        RUBYINTEGER.attr_hash => RUBYINTEGER,
        RUBYFLOAT.attr_hash => RUBYFLOAT,
        RUBYBOOLEAN.attr_hash => RUBYBOOLEAN,
        RUBYNUMERIC.attr_hash => RUBYNUMERIC,
      }
      @@unknowncount = 0
    end

    def self.find_v(dag, name, attrs)

      md5 = Digest::MD5.new
      # just hash it by name
      md5.update name

      verts = dag.vertices.select{|v| v.payload[:name] == name}
      e = verts.blank? ? dag.add_vertex({name: name, md5: md5.hexdigest}) : verts.first

      e
    end

    # Create a new, or return an existing, Entity named name that supports all fields in obj_hash.
    # Optionally, options can be supplied:
    # * :forcenumeric => true - Use RUBYNUMERIC instead of RUBYINTEGER / RUBYFLOAT.
    #
    # Note: Contained JSON Objects and Arrays will be recursively parsed into Entity and Collection instances.
    def self.parse_from(name, obj_hash, dag,options = {})
      ob = self.new(name)
      obj_hash.each do |k,v|

        orig = k
        k = k.gsub(/[^A-Za-z0-9_]/, "_")

        if v.kind_of?(Array)


          v1 = self.find_v(dag,name,[])
          v2 = self.find_v(dag,k,[])


          begin
            dag.add_edge from: v1, to: v2
          rescue

          end

          att = Collection.parse_from(k, v, dag, options)

        elsif v.kind_of?(String)
          att = RUBYSTRING
        elsif v.kind_of?(Integer) && !options[:forcenumeric]
          att = RUBYINTEGER
        elsif v.kind_of?(Float) && !options[:forcenumeric]
          att = RUBYFLOAT
        elsif (v.kind_of?(Integer) || v.kind_of?(Float)) && options[:forcenumeric]
          att = RUBYNUMERIC
        elsif !!v==v
          att = RUBYBOOLEAN
        elsif v.kind_of?(Hash)


          v_keys = v.keys

          v1 = self.find_v(dag, name, [])
          v2 = self.find_v(dag,k, [])

          begin
            dag.add_edge from: v1, to: v2
          rescue

          end

          att = self.parse_from(k, v, dag,options)
        elsif v==nil
          att = RUBYNIL
        end

        att.original_name = orig if orig != k
        ob.attributes[k] = att
      end

      x = ob.attr_hash
      if @@objs.has_key?(x)
        # merge previous attr hashes
        existing_object = @@objs[x]
        existing_object.attributes.merge!(ob.attributes)

        return @@objs[x]
      else
        @@objs[x] = ob
        return ob
      end

    end

    # Return the type cache of all Entity objects.
    # This is a Hash of +hash_attr+ values to +Entity+ instances.
    def self.entities
      @@objs
    end

    # Return a string of the form 'Unknown<x>' where <x> is a globally unique sequence.
    def self.get_next_unknown
      @@unknowncount ||= 0
      @@unknowncount += 1
      "Unknown#{@@unknowncount}"
    end

    # Return a string of the form ' (<y>)' where <y> is the original_name of the Entity
    def comment
      x = @name
      x += " (#{@original_name})" unless @original_name.nil?
      x
    end

    reset_parse
  end
end