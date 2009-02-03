$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

# This allows us to call blah(&:some_method) instead of blah{|i| i.some_method }
unless Symbol.instance_methods.include?('to_proc')
  class Symbol
    def to_proc
      Proc.new {|obj| obj.send(self) }
    end
  end
end

module HashMapper
  VERSION = '0.0.2'
  
  def maps
    @maps ||= []
  end
  
  def map(from, to, using=nil, &filter)
    self.maps << Map.new(from, to, using)
    to.filter = filter if block_given? # Useful if just one block given
  end
  
  def from(path, &filter)
    path_map = PathMap.new(path)
    path_map.filter = filter if block_given? # Useful if two blocks given
    path_map
  end
  
  alias :to :from
  
  def using(mapper_class)
    mapper_class
  end
  
  def normalize(a_hash)
    perform_hash_mapping a_hash, :normalize
  end

  def denormalize(a_hash)
    perform_hash_mapping a_hash, :denormalize
  end

  protected
  
  def perform_hash_mapping(a_hash, meth)
    output = {}
    a_hash = symbolize_keys(a_hash)
    maps.each do |m|
      m.process_into(output, a_hash, meth)
    end
    output
  end
  
  # from http://www.geekmade.co.uk/2008/09/ruby-tip-normalizing-hash-keys-as-symbols/
  #
  def symbolize_keys(hash)
    hash.inject({}) do |options, (key, value)|
      options[(key.to_sym rescue key) || key] = value
      options
    end
  end
  
  # Contains PathMaps
  # Makes them interact
  #
  class Map
    
    attr_reader :path_from, :path_to, :delegated_mapper
    
    def initialize(path_from, path_to, delegated_mapper = nil)
      @path_from, @path_to, @delegated_mapper = path_from, path_to, delegated_mapper
    end
    
    def process_into(output, incoming_hash, meth = :normalize)
      paths = [path_from, path_to]
      paths.reverse! unless meth == :normalize
      value = paths.first.inject(incoming_hash){|h,e| h[e]}
      value = delegate_to_nested_mapper(value, meth) if delegated_mapper
      add_value_to_hash!(output, paths.last, value)
    end
    
    protected
    
    def delegate_to_nested_mapper(value, meth)
      v = if value.kind_of?(Array)
        value.map {|h| delegated_mapper.send(meth, h)}
      else
        delegated_mapper.send(meth, value)
      end
    end
    
    def add_value_to_hash!(hash, path, value)
      path.inject(hash) do |h,e|
        if h[e]
          h[e]
        else
          h[e] = (e == path.last ? path.apply_filter(value) : {})
        end
      end
    end
    
  end
  
  # contains array of path segments
  #
  class PathMap
    include Enumerable
    
    attr_reader :segments
    attr_writer :filter
    
    def initialize(path)
      @path = path.dup
      @segments = parse(path)
      @filter = lambda{|value| value}# default filter does nothing
    end
    
    def apply_filter(value)
      @filter.call(value)
    end
    
    def each(&blk)
      @segments.each(&blk)
    end
    
    def last
      @segments.last
    end
    
    private
    
    def parse(path)
      path.sub(/^\//,'').split('/').map(&:to_sym)
    end
    
  end
  
end