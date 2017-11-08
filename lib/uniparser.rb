# Author::      Pavel Nazarov <pnazarov@gmail.com>
# Copyright::   Copyright (c) 2017 Pavel Nazarov
# License::     MIT
# URL::         https://github.com/alsvartr

# Simple and straightforward config & cli options parser
# Based on ruby-parseconfig class by BJ Dierkes <derks@datafolklabs.com>
# https://github.com/datafolklabs/ruby-parseconfig

class UniParser

      attr_accessor :config_file, :delim, :cli_desc, :banner, :groups, :cli, :config, :params, :merged

      def initialize(config_file = nil)
            self.config_file = config_file

            self.groups = []
            self.cli = Hash[:free => ARGV]
            self.config = Hash[]
            self.merged = Hash[]
            self.params = Hash[:cli => self.cli, :config => self.config, :merged => self.merged]
            self.cli_desc = Array.new
      end

      def parse_all(config_file = nil, cli = ARGV)
            config_file = self.config_file if self.config_file != nil
            return nil if config_file == nil
            self.config_file = config_file

            self.cli[:free] = cli

            self.parse_file(config_file)
            self.parse_cli([], nil)
            #self.merge()
      end

      def parse_file(config_file = nil)
            config_file = self.config_file if self.config_file != nil
            return nil if config_file == nil
            self.config_file = config_file

            self.validate_config
            self.import_config
            #self.merge()
      end

      def parse_cli(names, desc, next_is_val = true, merge_with = nil)
            merge = lambda { |val|
                  # FIXME: add dynamic hash merging
                  if merge_with.size == 1
                        self.merged[:"#{merge_with[0]}"] = self.cli[:"#{gsub_param}"]
                  else
                        self.merged[:"#{merge_with[0]}"] = Hash[] if self.merged[:"#{merge_with[0]}"].class.to_s != "Hash"
                        self.merged[:"#{merge_with[0]}"][:"#{merge_with[1]}"] = val
                  end
            }
            merge.call( self.config[:"#{merge_with[0]}"][:"#{merge_with[1]}"] ) if merge_with != nil

            self.cli_desc.push ( Array[names, desc, next_is_val] ) if names.size != 0
            return nil if self.cli[:free].size == 0

            self.cli[:free].each_with_index do |param, index|
                  next if not names.include? param

                  gsub_param = names[1].gsub(/^-+/, "")
                  if next_is_val
                        self.cli[:"#{gsub_param}"] = self.cli[:free][index + 1]
                        self.cli[:free].delete_at( index + 1 )
                  else
                        self.cli[:"#{gsub_param}"] = true
                  end
                  self.cli[:free].delete_at(index)

                  merge.call( self.cli[:"#{gsub_param}"] ) if merge_with != nil
            end
      end

      def bound_cli(opt_name, opt_index)
            return nil if opt_index >= self.cli[:free].size
            self.cli[:"#{opt_name}"] = self.cli[:free][opt_index]
      end

      def types(val)
            return nil if val == nil

            if val.class.to_s == "Hash"
                  val.each do |h_var, h_val|
                        val[h_var] = self.types(h_val) # recursion rocks!
                  end
                  return val
            end

            case val
            when /^[0-9]+$/
                  val = val.to_i
            when /^true$/
                  val = true
            when /^false$/
                  val = false
            end

            return val
      end

      def types!()
            self.params.each {|var, val| self.params[var] = self.types(val) }
      end

      def show_banner(sort = false)
            puts "#{self.banner}\n\n" if self.banner

            out = Array.new
            out_desc = Array.new
            str_len = 0
            self.cli_desc.sort! if sort

            self.cli_desc.each do |arr|
                  all_names = ""
                  names = arr[0]
                  desc = arr[1]
                  next_is_val = arr[2]

                  names.each {|name| all_names += name.ljust(7) }
                  all_names += "  [value]" if next_is_val
                  str_len = all_names.size if all_names.size > str_len

                  out.push(all_names)
                  out_desc.push(desc)
            end
            out.each_with_index {|str, index| print "".ljust(5); print "#{str.ljust(str_len*2)}#{out_desc[index]}\n" }
      end

      def validate_config()
            unless File.readable?(self.config_file)
                  raise Errno::EACCES, "#{self.config_file} is not readable"
            end

            # FIXME: need to validate contents/structure?
      end

      def import_config()
            # The config is top down.. anything after a [group] gets added as part
            # of that group until a new [group] is found.
            group = nil
            open(self.config_file) { |f| f.each_with_index do |line, i|
                  line.strip!

                  # force_encoding not available in all versions of ruby
                  begin
                        if i.eql? 0 and line.include?("\xef\xbb\xbf".force_encoding("UTF-8"))
                              line.delete!("\xef\xbb\xbf".force_encoding("UTF-8"))
                        end
                  rescue NoMethodError
                  end

                  unless (/^\#/.match(line))
                        if(/\s*=\s*/.match(line))
                              param, value = line.split(/\s*=\s*/, 2)
                              var_name = "#{param}".chomp.strip
                              value = value.chomp.strip
                              new_value = ''
                              if (value)
                                    if value =~ /^['"](.*)['"]$/
                                          new_value = $1
                                    else
                                          new_value = value
                                    end
                              else
                                    new_value = ''
                              end

                              if group
                                    self.add_to_group(group, var_name, new_value)
                              else
                                    self.add(var_name, new_value)
                              end

                        elsif(/^\[(.+)\]$/.match(line).to_a != [])
                              group = /^\[(.+)\]$/.match(line).to_a[1]
                              self.add(group, {})
                        end
                  end
            end }
      end

      def get_value(param)
            puts "ParseConfig Deprecation Warning: get_value() is deprecated. Use " + \
            "config['param'] or config['group']['param'] instead."
            return self.params[param]
      end

      def [](param)
            return self.params[param]
      end

      def get_params()
            return self.params.keys
      end

      def get_groups()
            return self.groups
      end

      def add(param_name, value)
            if value.class == Hash
                  if self.config.has_key?(param_name)
                        if self.config[:"#{param_name}"].class == Hash
                              self.config[:"#{param_name}"].merge!(value)
                        elsif self.config.has_key?(param_name)
                              if self.config[:"#{param_name}"].class != value.class
                                    raise ArgumentError, "#{param_name} already exists, and is of different type!"
                              end
                        end
                  else
                        self.config[:"#{param_name}"] = value
                  end
                  if ! self.groups.include?(param_name)
                        self.groups.push(param_name)
                  end
            else
                  self.config[:"#{param_name}"] = value
            end
      end

      def add_to_group(group, param_name, value)
            if ! self.groups.include?(group)
                  self.add(group, {})
            end
            self.config[:"#{group}"][:"#{param_name}"] = value
      end

      def write(output_stream=STDOUT, quoted=true)
            self.params.each do |name,value|
                  if value.class.to_s != 'Hash'
                        if quoted == true
                              output_stream.puts "#{name} = \"#{value}\""
                        else
                              output_stream.puts "#{name} = #{value}"
                        end
                  end
            end
            output_stream.puts "\n"

            self.groups.each do |group|
                  output_stream.puts "[#{group}]"
                  self.params[group].each do |param, value|
                        if quoted == true
                              output_stream.puts "#{param} = \"#{value}\""
                        else
                              output_stream.puts "#{param} = #{value}"
                        end
                  end
                  output_stream.puts "\n"
            end
      end

      def eql?(other)
            self.params == other.params && self.groups == other.groups
      end
      alias == eql?
end
