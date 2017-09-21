require 'digest/md5'
require 'json'
require 'optparse'
require 'active_support/all'

module JSON2Ruby
  # The RubyWriter class contains methods to output ruby code from a given Entity.
  class RubyWriter

    def self.camel_case(s)
      return s if s !~ /_/ && s =~ /[A-Z]+.*/
      s.split('_').map{|e| e.capitalize}.join
    end
    # Return a String containing a Ruby class/module definition for the given Entity.
    # Optionally, supply indent to set the indent of the generated code in spaces,
    # and supply a Hash of options as follows:
    # * :modules - Boolean if true, generate Ruby +module+ files instead of classes.
    # * :require - Array of String items, each of which will generate a `require '<x>'` statement for each item
    # * :superclass_name - String, if supplied, the superclass of the class to geneerate
    # * :extend - Array of String items, each of which will generate a `extend '<x>'` statement for each item in the class
    # * :include - Array of String items, each of which will generate a `include '<x>'` statement for each item in the class
    def self.to_code(entity, indent = 0, options = {})
      x = ""
      if options.has_key?(:require)
        options[:require].each { |r| x += "require '#{r}'\r\n" }
        x += "\r\n"
      end
      idt = (' '*indent)
      x += "#{(' '*indent)}#{options[:modules] ? "module" : "class"} #{self.camel_case(entity.name).upcase_first}"
      x += " < #{options[:superclass_name]}" if options.has_key?(:superclass_name)
      x += "\r\n"
      if options.has_key?(:extend)
        options[:extend].each { |r| x += "#{(' '*(indent+2))}extend #{r}\r\n" }
        x += "\r\n"
      end
      if options.has_key?(:include)
        options[:include].each { |r| x += "#{(' '*(indent+2))}include #{r}\r\n" }
        x += "\r\n"
      end
      x += "\r\n"
      x += attributes_to_ruby(entity, indent+2, options)
      x += "\r\n"
      x += attributes_to_constructor(entity, indent+2, options)
      x += "\r\n"
      x += "#{(' '*indent)}end\r\n"
      x
    end

    # Return a String containing the Ruby code for each Attribute definition for in the supplied Entity.
    # Optionally, supply indent to set the indent of the generated code in spaces,
    # and supply a Hash of options as follows:
    # * :attributemethod - String, the method to call to define attributes
    # * :collectionmethod - String, the method to call to define collections
    # * :includetypes - Boolean if true, include the string of the Attribute type as a second parameter to the definition call.
    # * :namespace - String, the namespace of the type classes in the format 'Module::SubModule'...
    def self.attributes_to_ruby(entity, indent = 0, options = {})

      dag = JSON2Ruby::Entity.dag
      verts = dag.vertices.select{|v| v.payload[:name] == entity.name}
      e = verts.blank? ? dag.add_vertex({name: name}) : verts.first

      foo = []
      entity.attributes.each do |k,v|
        foo << k
      end

      e.payload[:attrs] = foo

      ident = (' '*indent)
      x = "#{ident}attr_accessor "

      attrs = []
      entity.attributes.each do |k,v|

        attr_name = k.underscore

        if !attrs.include? ":#{attr_name}"
          attrs << ":#{attr_name}"
        end

      end

      attr_string = apply_margins(attrs, x)

      x += attr_string
      x += "\r\n"
      x
    end

    def self.attributes_to_constructor(entity, indent = 0, options = {})
      ident = (' '*indent)
      constructor = "#{ident}def initialize("

      attrs = []
      ats = []
      entity.attributes.each do |k,v|

        attr_name = k.underscore

        e = ''
        if v.kind_of?(Collection)
          e = '[]'
        end


        attrs << "#{attr_name}:#{e}"


        ats << "@#{attr_name} = #{attr_name}"

      end

      attr_string = apply_margins(attrs, constructor)

      constructor += attr_string
      constructor += ")"
      constructor += "\r\n"
      constructor += "\r\n"
      constructor += "#{ats.map{|at| "#{ident}  #{at}"}.join("\r\n")}"
      constructor += "\r\n"
      constructor += "#{ident}end\r\n"
      constructor
    end

    def self.apply_margins(attrs, constructor)
      attr_string = ""
      curr = ""

      for str in attrs do
        curr += str
        if (curr.size + str.size + constructor.size) > 90
          attr_string += "\r\n#{' '*constructor.size}"
          curr = ''
        end
        attr_string += str + ', '

      end

      attr_string = attr_string.sub(/, $/, '')
    end
  end
end