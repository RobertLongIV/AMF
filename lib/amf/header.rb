module AMF
  class Header
    attr_accessor :target, :required, :data

    def initialize( target, required, data )
      @target = target
      @required = required
      @data = data
    end

    def to_hash
      { 'name' => self.target, 'required' => self.required, 'data' => self.data }
    end

    # needed this method, it is a bit of a hack
    def each
      self.to_hash.each
    end
  end
end

