require 'digest/md5'
require 'json'
require 'optparse'
require 'active_support/all'

module JSON2Ruby
  # The RubyWriter class contains methods to output ruby code from a given Entity.
  class FactoryWriter

    def self.to_do
      @@TODO ||= []
    end

    def self.digest(entity, dependency_graph)

      todos = self.to_do

      dependency_graph[entity].each do |ent, v|

        if v.is_a?(Hash) && !v[:relation].blank? && v[:relation] == "has_one"


          v[:relational_attrs].each do |name, e|
            if !e.is_a?(JSON2Ruby::Primitive)
              todos << name

              self.digest(name, dependency_graph)
            end
          end

        end

        if v.is_a?(Hash) && !v[:relation].blank? && v[:relation] == "has_many"

          if !e.is_a?(JSON2Ruby::Primitive)
            todos << name
            self.digest(name, dependency_graph)
          end

        end
      end


      todos
    end

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
    def self.to_code(entity, dependency_graph, indent = 0, options = {})
      x = ""
      if options.has_key?(:require)
        options[:require].each { |r| x += "require '#{r}'\r\n" }
        x += "\r\n"
      end
      idt = (' '*indent)
      x += "#{(' '*indent)}#{options[:modules] ? "module" : "class"} #{self.camel_case(entity.to_s).upcase_first}Factory"

      x += "\r\n"


      attributes = JSON2Ruby::Entity.entities[JSON2Ruby::Entity.get_md5(entity)].attributes
      # puts attributes.keys.to_json

      x += attributes_to_ruby(entity, indent+2, attributes.keys,dependency_graph)
      x += "#{(' '*indent)}end\r\n"
      x
    end

    def self.attributes_to_ruby(entity, indent, attributes, dependency_graph)

      x = "#{" "*indent}def self.build("

      attrs = []
      needed_factories = []
      attributes.each do |k,v|

        attr_name = k

        if !attrs.include? "#{attr_name}"
          attrs << "#{attr_name}:"
        end

        # if dependency_graph[k].is_a?(Hash)
        #   needed_factories << "@#{k.underscore} = #{k}Factory.build(#{k})"
        # end

      end

      attr_string = self.apply_margins(attrs, x)
      needed_factory_string = needed_factories.join("\r\n#{" "*2*indent}")

      x += attr_string

      x += ")"
      x += "\r\n"
      x += "#{" "*2*indent}#{needed_factory_string}"
      x += "\r\n#{" "*indent}end"
      x += "\r\n"
      x
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