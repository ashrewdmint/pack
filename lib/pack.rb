class Pack
  DIR   = File.dirname(__FILE__)
  TYPES = %w(js css)
  
  def self.js(location, destination)
    pack :js, location, destination
  end
  
  def self.css(location, destination)
    pack :css, location, destination
  end
  
private
  
  def self.pack(type, location, destination)
    return false unless TYPES.include?(type.to_s)
    
    location += '/' if location.split('').last != '/'
    
    begin
      load_file = File.new(location + 'load.txt')
      files     = parse_load_file(load_file, type)
      combined  = read_files(files)
    rescue
      raise Exception, "Could not find #{location}load.txt"
    end
    
    case type
    when :css
      puts "Compressing CSS"
      compressed = minify_css(combined)
    when :js
      puts "Compressing Javascript"
      compressed = compress_javascript(files)
    end
    
    # Print out comparison table
    compare_strings :original => combined, :compressed => compressed
    
    # Save file
    dirs = destination.split('/')
    dirs.pop # Remove the last file
    
    # Make directories if they don't exist
    dirs.each_with_index do |dir, i|
      path = '/' + dirs.slice(0, i + 1).join('/')
      unless File.directory? path
        puts "Creating #{dir} directory"
        Dir.mkdir(path) 
      end
    end
    
    puts "Saving to #{destination}"
    File.open(destination, 'w') {|file| file.write compressed}
  end
  
  def self.parse_load_file(file, type)
    extension = Regexp.new(".#{type}")
    array  = []
    output = []
    dir    = File.dirname(file.path) + '/'
    file.read.split("\n").each do |line|
      # Skip comments
      next if line =~ /^#|^$/
      new_file = nil
      
      # Loop through directory if path ends in *
      if line =~ /\*$/
        path = line.gsub!(/\*$/, '');
        Dir.new(dir + path).each do |f|
          # Skip invisible files
          if f =~ extension and f.split('').first != '.'
            output << path + f
            array  << dir + path + f
          end
        end
      # Add file normally
      else
        if line =~ extension
          output << line
          array  << dir + line
        end
      end
    end
    
    puts 'Reading ' + file.path
    puts output.collect {|line| "  - #{line}"}.join("\n")
    array
  end
  
  def self.read_files(array)
    contents = ''
    array.each do |file|
      contents += File.read(file)
    end
    contents
  end
  
  def self.minify_css(css)
    # Remove whitespace
    css.gsub!(/[\r\t\n]/, '')
    css.gsub!(/\s*([\{:;,\}])\s*/, '\1')

    # Remove comments
    css.gsub!(Regexp.new('/\*[^*]*\*+([^/][^*]*\*+)*/'), '')

    # Remove semicolons next to end brackets
    css.gsub(/;\}/, '}')
  end
  
  def self.compress_javascript(files)
    files = files.collect { |file| "--js=#{file}" }.join(' ')
    `java -jar #{DIR}/java/compiler.jar --warning_level=QUIET #{files}`
  end
  
  def self.compare_strings(hash)
    summary = 'Difference'
    
    # Find longest name
    length = summary.length
    hash.each_key do |name|
      name = name.to_s
      length = name.length if name.length > length
    end
    # Pad length for spacing
    length += 4
    
    bytes_array = []
    hash.each_pair do |name, value|
      # Count bytes
      bytes = 0
      value.each_byte {|b| bytes += 1}
      hash[name] = bytes
      bytes_array << bytes
    end
    
    # Sort by number of bytes descending
    stats = []
    bytes_array.sort!.reverse!.each do |bytes|
      name = hash.invert[bytes].to_s.capitalize.ljust(length)
      stats << name + bytes.to_s
    end
    
    # Find percentage
    first = bytes_array.first
    last  = bytes_array.last
    percentage = 100 - ((last / first.to_f) * 100)
    percentage = (percentage * 100).round / 100.to_f
    stats << summary.ljust(length) + "#{first - last} (#{percentage}%)"
    
    stats.each {|stat| puts "  - #{stat}"}
  end
end