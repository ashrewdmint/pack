# Pack
#   by Andrew Smith

class Pack
  DIR   = File.dirname(__FILE__)
  TYPES = %w(js css)
  
  def self.pack(file)
    self.parse_load_file(file).each do |collection|
      
      content = read_files(collection[:files])
      
      verb = collection[:mode] == 'compress' ? 'Compressing' : 'Combining'
      puts "#{verb} #{collection[:target_file_short]}..."
      puts '  - ' + collection[:short_files].join("\n  - ")
      
      if collection[:mode] == 'compress'
        old_content = content
        
        if collection[:type] == 'js'
          content = compress_javascript collection[:files]
        else
          content = minify_css(content)
        end
        
        comparison = compare_strings old_content, content
        bytes = comparison[:difference] == 1 ? 'byte' : 'bytes'
        puts "#{comparison[:difference]} #{bytes} of #{comparison[:first]} saved (#{comparison[:percent_difference]}%)"
      end
      
      # Write file
      File.open(collection[:target_file], 'w') {|file| file.write content}
    end
  end

private
  
  def self.parse_load_file(path)
    file   = File.new(path)
    dir    = File.dirname(file.path) + '/'
    result = []
    extension = nil
    current_file = nil
    current_collection = nil
    current_file_array = []
    
    file.read.split("\n").each do |line|
      # Skip comments and empty lines, remove whitespace
      line.strip!
      next if line.split('').first == '#' || line == ''
      
      # Parse "@" statements
      if line =~ /^@/
        matches  = line.match /@([^ ]+) (.*)/
        mode     = matches[1].to_s
        new_path = matches[2].to_s
        
        # Make sure a mode and a new_path is supplied.
        # Otherwise, ignore this line.
        
        unless mode.empty? or new_path.empty?
          # The type is the "js" in "something.js"
          type = get_file_type(new_path)
          extension = Regexp.new ".#{type}$"
          
          raise Exception, 'Invalid type' unless TYPES.include? type
          
          current_file = ensure_absolute_path(new_path, dir)
          
          current_collection = {
            :mode              => mode,
            :files             => [],
            :type              => type,
            :target_file       => current_file,
            :target_file_short => new_path,
            :short_files       => []
          }
          
          result << current_collection
          current_file_array = current_collection[:files]
        end
      elsif current_file
        # Loop through directory if path ends in *
        if line =~ /\*$/
          line.gsub!(/\*$/, '')
          short_path = line
          path       = ensure_absolute_path(line, dir)
          
          Dir.new(path).each do |f|
            # Skip invisible files or files with the wrong type
            if f =~ extension and f.split('').first != '.'
            current_collection[:short_files] << short_path + f
            current_file_array << ensure_absolute_path(path + f, dir)
            end
          end
        else
          if line =~ extension
            current_collection[:short_files] << line
            current_file_array << ensure_absolute_path(line, dir)
          end
        end
      end
      
      # Make sure the file we write to never gets read
      current_file_array.delete(current_file)
    end
    
    puts 'Reading ' + file.path
    result
  end
  
  def self.ensure_absolute_path(path, absolute_prefix)
    return path[0, 1] == '/' ? path : absolute_prefix + path
  end
  
  def self.read_files(array)
    contents = ''
    array.each do |file|
      contents += File.read(file)
    end
    contents
  end
  
  def self.get_file_type(filename)
    filename.match(/\.([^\.]+$)/)[1]
  end
  
  def self.compress_javascript(files)
    files = files.collect { |file| "--js=#{file}" }.join(' ')
    `java -jar #{DIR}/java/compiler.jar --warning_level=QUIET #{files}`
  end
  
  def self.minify_css(css)
    # Remove whitespace
    css.gsub!(/[\r\t\n]/, '')
    css.gsub!(/\s*([\{:;,\}])\s*/, '\1')

    # Remove comments
    css.gsub!(Regexp.new('/\*[^*]*\*+([^/][^*]*\*+)*/'), '')

    # Remove semicolons next to end brackets
    css.gsub(/;\}/, '}')
    
    # Remove empty rules
    css.gsub(/[^\{\}]+\{\}/, '')
  end
  
  def self.compare_strings(first, second)
    [first, second].each_with_index do |string, index|
      bytes = 0
      string.each_byte {|b| bytes += 1}
      
      if index == 0
        first = bytes
      else
        second = bytes
      end
    end
    
    percent_difference = ((first - second).to_f / first) * 100
    percent_difference = (percent_difference * 100).round / 100.to_f
    
    return {
      :first      => first,
      :second     => second,
      :difference => first - second,
      :percent_difference => percent_difference
    }
  end
end