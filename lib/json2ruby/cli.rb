require 'digest/md5'
require 'json'
require 'optparse'
require 'DAG'

module JSON2Ruby

  # The CLI (Command Line Interface) functionality class for the json2ruby executable
  class CLI

    def self.dep_graph
      @@DEP_GRAPH ||= {}
    end


    # Run the json2ruby command, using arguments in ARGV.
    def self.run

      puts "json2ruby v#{VERSION}\n"

      # Do the cmdline options
      options = get_cli_options

      # Ensure Output Directory
      options[:outputdir] = File.expand_path(options[:outputdir], File.dirname(__FILE__))      
      ensure_output_dir(options)

      # Parse Files
      rootclasses = parse_files(options)

      # Write out Ruby (see what I'm doing here?)
      writer = JSON2Ruby::RubyWriter

      # Write Output
      write_files(rootclasses, writer, options)
    end

    # Create the output directory with the options[:outputdir] if it does not exist.
    def self.ensure_output_dir(options)
      puts "Output Directory: #{options[:outputdir]}" if options[:verbose]
      unless Dir.exists?(options[:outputdir])
        puts "Creating Output Directory..." if options[:verbose]
        Dir.mkdir(options[:outputdir])
      end
    end

    # Process ARGV for command line switches and return the options hash.
    def self.get_cli_options
      options = {}
      OptionParser.new do |opts|
        opts.banner = "Usage: #{$0} [options] <file.json> [<file.json>....]"

        opts.on("-o", "--outputdir OUTPUTDIR", "Output directory") do |v|
          options[:outputdir] = v
        end

        opts.on("-n", "--namespace MODULENAME", "Module namespace path") do |v|
          options[:namespace] = v
        end

        opts.on("-s", "--superclass SUPERCLASS", "Class ancestor") do |v|
          options[:superclass_name] = v
        end

        opts.on("-r", "--require REQUIRE", "Require module in file") do |v|
          options[:require] ||= []
          options[:require] << v
        end

        opts.on("-i", "--include INCLUDE", "Include Class/Module in file") do |v|
          options[:include] ||= []
          options[:include] << v
        end

        opts.on("-e", "--extend EXTEND", "Extend from Class/Module in file") do |v|
          options[:extend] ||= []
          options[:extend] << v
        end

        opts.on("-M", "--modules", "Create Modules, not classes") do |v|
          options[:modules] = true
        end

        opts.on("-a", "--attributemethod METHODNAME", "Use attribute method instead of attr_accessor") do |v|
          options[:attributemethod] = v
        end

        opts.on("-c", "--collectionmethod METHODNAME", "Use collection method instead of attr_accessor") do |v|
          options[:collectionmethod] = v
        end

        opts.on("-t", "--types", "Include type in attribute definition call") do |v|
          options[:includetypes] = true
        end

        opts.on("-b", "--baseless", "Don't generate classes/modules for the root JSON in each file") do |v|
          options[:baseless] = true
        end

        opts.on("-f", "--forceoverwrite", "Overwrite Existing files") do |v|
          options[:forceoverwrite] = v
        end

        opts.on("-N", "--forcenumeric", "Use Numeric instead of Integer/Float") do |v|
          options[:forcenumeric] = v
        end

        opts.on("-v", "--verbose", "Verbose") do |v|
          options[:verbose] = v
        end

        opts.on("-g", "--buildClass class", "class builder") do |v|
          options[:build] = v
        end
      end.parse!

      # Defaults
      options[:outputdir] ||= File.expand_path("./classes")
      options[:namespace] ||= ""
      options[:attributemethod] ||= "attr_accessor"
      options[:collectionmethod] ||= "attr_accessor"
      options[:includetypes] ||= false
      options[:baseless] ||= false
      options[:forceoverwrite] ||= false
      options[:verbose] ||= false

      options[:modulenames] = options[:namespace].split("::")

      options
    end


    # Parse all JSON files in ARGV and build the Entity cache, using the supplied options Hash.
    def self.parse_files(options)
      # Reset the object cache
      Entity.reset_parse

      # Load and parse each JSON file
      puts "Parsing Files..." if options[:verbose]

      rootclasses = []

      dep_graph = self.dep_graph

      dag = JSON2Ruby::Entity.dag

      ARGV.each do |filename|
        filename = File.expand_path(filename)
        puts "Processing: #{filename}" if options[:verbose]

        file = File.read(filename)
        data_hash = JSON.parse(file)

        rootclasses << Entity.parse_from(File.basename(filename,'.*'), data_hash, dag, options, true)
      end


      dag.vertices.each_with_index do |v, _|

        if v.successors.size > 0
          successor_as_attrs = {}

          v.outgoing_edges.each do |e|

            successor_as_attrs[e.destination[:name]] = {relational_attrs: self.to_attributes(e.destination), relation: e[:properties][:type]}
          end

          dep_graph[v[:name]] = self.to_attributes(v).merge(successor_as_attrs)

        else
          dep_graph[v[:name]] = self.to_attributes(v)
        end
      end




      rootclasses
    end

    def self.to_attributes(v)

      Entity.entities.has_key?(v[:md5]) ? Entity.entities[v[:md5]].attributes.dup : nil
    end

    # Write out all types in the Entity cache, except primitives and those contained in the 
    # rootclasses array, to the provided writer with the supplied options Hash.
    def self.write_files(rootclasses, writer, options)
      files = 0
      Entity.entities.each do |k,v|
        next if options[:baseless] and rootclasses.include?(v)

        display_entity(k,v) if options[:verbose] && !v.is_a?(Primitive)

        if v.is_a?(Entity)
          indent = 0
          out = ""
          options[:modulenames].each do |v|
            out += (' '*indent)+"module #{v}\r\n"
            indent += 2
          end
          out += writer.to_code(v, indent,options)
          while indent>0
            indent -= 2
            out += (' '*indent)+"end\r\n"
          end

          filename = options[:outputdir]+"/#{self.underscore(v.name.to_s)}.rb"
          if File.exists?(filename) && !options[:forceoverwrite]
            $stderr.puts "File #{filename} exists. Use -f to overwrite."
          else
            File.write(filename, out)
            files += 1
          end
        end
      end

      if !self.dep_graph[options[:build]].blank?

        dag = JSON2Ruby::Entity.dag

        JSON2Ruby::FactoryWriter.digest(options[:build], dep_graph, dag)
        JSON2Ruby::FactoryWriter.to_do << options[:build]


        JSON2Ruby::FactoryWriter.to_do.each do |todo|
          filename = options[:outputdir]+"/#{self.underscore(todo)}_factory.rb"
          factory_out = ""
          indent = 0
          options[:modulenames].each do |v|
            factory_out += (' '*indent)+"module #{v}\r\n"
            indent += 2
          end
          factory_out += JSON2Ruby::FactoryWriter.to_code(todo, self.dep_graph, indent, options, dag)
          while indent>0
            indent -= 2
            factory_out += (' '*indent)+"end\r\n"
          end

          if File.exists?(filename) && !options[:forceoverwrite]
            $stderr.puts "File #{filename} exists. Use -f to overwrite."
          else
            File.write(filename, factory_out)
            files += 1
          end
        end

      end

      # Done
      puts "Done, Generated #{files} file#{files==1 ? '' : 's'}"
    end



    def self.underscore(s)
      s.gsub(/::/, '/').gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').gsub(/([a-z\d])([A-Z])/,'\1_\2').tr("-", "_").downcase
    end

    # Display the Entity supplied in ent with the supplied hash value hsh to STDOUT  
    def self.display_entity(hsh, ent)
      puts "- #{ent.name} (#{ent.class.short_name} - #{hsh})"
      if ent.is_a?(Entity)
        ent.attributes.each { |ak,av| puts "  #{ak}: #{av.name}" }
      elsif ent.is_a?(Collection)
        puts "  (Types): #{ent.ruby_types.map { |h,ent| ent.name }.join(',')}"
      end
    end
  end
end

