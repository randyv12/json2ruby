require 'digest/md5'
require 'json'
require 'optparse'
require 'active_support/all'

module JSON2Ruby
  # The RubyWriter class contains methods to output ruby code from a given Entity.
  class FactoryWriter

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
      attributes = dependency_graph[entity].keys
      x += attributes_to_ruby(entity, indent+2, attributes)
      x += "#{(' '*indent)}end\r\n"
      x
    end
    def self.attributes_to_ruby(entity, indent, attributes)

      x = "#{" "*indent}def self.build("

      attrs = []
      attributes.each do |k,v|

        attr_name = k

        if !attrs.include? "#{attr_name}"
          attrs << "#{attr_name}:"
        end

      end

      attr_string = attrs.join(",")

      x += attr_string
      x += ")"
      x += "\r\nend"
      x += "\r\n"
      x
    end

  end
end