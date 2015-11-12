module AMF
  class Message
    attr_accessor :targetURL, :responseURL, :data

    def initialize( targetURL, responseURL, data )
      @targetURL = targetURL
      @responseURL = responseURL
      @data = data
    end

    def to_hash
      { 'targetUri' => self.targetURL, 'responseUri' => self.responseURL, 'data' => recursive_marshal( data ) }
    end

    private

    def recursive_marshal( data )
      ret = Hash.new
      if data.class == OpenStruct
        data.marshal_dump.each{ |k,v|
          ret[k] = recursive_marshal v
        }
      elsif data.class == Hash
        data.each{ |k,v|
          ret[k] = recursive_marshal v
        }
      else
        ret = data
      end

      ret
    end

  end
end

