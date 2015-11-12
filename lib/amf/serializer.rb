module AMF
  class Serializer

    attr_accessor :data

    def initialize( headers, messages, amfVersion )
      @headers      = headers
      @messages     = messages
      @amfVersion   = amfVersion
      @data         = String.new

      writeInt 0 # start if off right

      # start writing the headers
      writeInt @headers.count
      @headers.each do |header|
        resetReferences
        writeUTF header.target
        if header.required == true
          writeByte 1
        else
          writeByte 0
        end
        tmpdata = @data
        @data = String.new
        writeData header.data
        serializedHeader = @data
        @data = tmpdata
        writeLong serializedHeader.length
        @data += serializedHeader
      end

      # and write the data
      writeInt @messages.count
      @messages.each do |message|
        resetReferences
        writeUTF message.targetURL
        writeUTF message.responseURL
        tmpdata = @data
        @data = String.new
        writeData message.data
        serializedMessage = @data
        @data = tmpdata
        writeLong serializedMessage.length
        @data += serializedMessage
      end
    end

    private

    def writeData( data )
      if @amfVersion == AMF3_VERSION
        writeByte( AMF0_AMF3_MARKER )
        writeAMF3Data( data )
      else
        raise "Unsupported writing AMF0 types"
      end
    end

    def writeAMF3Data( data )
      case data.class.to_s
        when 'Fixnum'
          writeAMF3Number( data )
        when 'Float'
          writeByte( AMF3_DOUBLE_MARKER )
          writeDouble( data )
        when 'String'
          writeByte( AMF3_STRING_MARKER )
          writeAMF3String( data )
        when 'FalseClass'
          writeByte( AMF3_FALSE_MARKER )
        when 'TrueClass'
          writeByte( AMF3_TRUE_MARKER )
        when 'NilClass'
          writeByte( AMF3_NULL_MARKER )
        when 'Time'
          writeAMF3Date( data )
        when 'Hash'
          writeAMF3Array( data )
        when 'OpenStruct'
          if data.send( AMF_FIELD_EXPLICIT_TYPE )
            writeAMF3TypedObject( data )
          else
            writeAMF3AnonymousObject( data )
          end
      else
         raise "Unknown data type: #{ data.class }"
      end
    end

    def writeByte( byte )
      @data << [ byte ].pack( 'c' )
    end

    def writeInt( int )
      @data << [ int ].pack( 'n' )
    end

    def writeLong( long )
      @data << [ long ].pack( 'N' )
    end

    def writeDouble( double )
     @data << [ double ].pack( 'd' ).reverse
    end

    def writeUTF( string )
      writeInt( string.length )
      @data << string
    end

    def writeLongUTF( string )
      writeLong( string.length )
      @data << string
    end

    def writeBoolean( bit )
      writeByte( AMF0_BOOLEAN_MARKER )
      writeByte( bit )
    end

    def writeString( string )
      if string.count < 65536
        writeByte( AMF0_STRING_MARKER )
        writeUFT( string )
      else
        writeByte( AMF0_LONG_STRING_MARKER )
        writeLongUTF( string )
      end
    end

    def writeNumber( number )
      writeByte( AMF0_NUMBER_MARKER )
      writeDouble( number.to_f )
    end

    def writeNull
      writeByte( AMF0_NULL_MARKER )
    end

    def writeUndefined
      writeByte( AMF0_UNDEFINED_MARKER )
    end

    def writeAMF3Int( int )
      int &= 0x1fffffff
      if int < 0x80
        data = int.chr
      elsif int < 0x4000
        data = ( int >> 7 & 0x7f | 0x80 ).chr + ( int & 0x7f ).chr
      elsif int < 0x200000
        data = ( int >> 14 & 0x7f | 0x80 ).chr + ( int >> 7 & 0x7f | 0x80 ).chr + ( int & 0x7f ).chr
      else
        data = ( int >> 22 & 0x7f | 0x80 ).chr + ( int >> 15 & 0x7f | 0x80 ).chr + ( int >> 8 & 0x7f | 0x80 ).chr + ( int & 0xff ).chr
      end

      @data += data
    end

    def writeAMF3String( string )
      if string.empty?
        writeByte( AMF3_NULL_MARKER )
      elsif ! handleReference( string, @storedStrings )
        writeAMF3Int( ( string.length << 1 | 1 ) )
        @data += string
      end
    end

    # in ruby speak this is time, but we go with the status quo
    def writeAMF3Date( date )
      writeByte AMF3_DATE_MARKER
      writeAMF3Int 1
      writeDouble date.to_f
    end

    def writeAMF3Array( array )
      if @storedObjects.keys.count <= AMF_MAX_STORED_OBJECTS
        @storedObjects[ @storedObjects.keys.count ] = @storedObjects.keys.count
      end

      # meh, so there is a whole boat of stuff that we're missing here -
      # arrays that are sparse, arrays with string 'keys'.  in my testing
      # I never saw any of those data types so just doing it the easy way
      writeByte( AMF3_ARRAY_MARKER )
      writeAMF3Int( ( array.count * 2 ) + 1 )
      array.select{ |x| x.class == String }.each do |key, value|
        writeAMF3String( key.to_s )
        writeAMF3Data( value )
      end
      writeAMF3String('')

      array.select{ |x| x.class == Fixnum }.each do |key,value|
        writeAMF3Data value
      end
    end

    def writeAMF3TypedObject( data )
      writeByte( AMF3_OBJECT_MARKER )
      if ! handleReference( data, @storedObjects )
        classname = data.send( AMF_FIELD_EXPLICIT_TYPE )
        if @className2TraitsInfo[ classname ].nil?
          propertyNames = Array.new
          data.marshal_dump.each do |key, value|
            if key[0] != "\0" and key.to_s != AMF_FIELD_EXPLICIT_TYPE
              propertyNames << key
            end
          end

          writeAMF3Int( propertyNames.count << 4 | 3 )
          writeAMF3String( classname )
          propertyNames.each do |p|
            writeAMF3String( p.to_s )
          end

          traitsInfo = { 'referenceId' => @className2TraitsInfo.keys.count, 'propertyNames' => propertyNames }
          @className2TraitsInfo[ classname ] = traitsInfo
        else
          traitsInfo = @className2TraitsInfo[ classname ]
          referenceId = traitsInfo[ 'referenceId' ]
          propertyNames = traitsInfo[ 'propertyNames' ]
          writeAMF3Int( referenceId << 2 | 1 )
        end

        propertyNames.each do |p|
          writeAMF3Data( data.marshal_dump[ p ] )
        end
      end
    end


    def writeAMF3AnonymousObject( data, doRef = true )
      writeByte( AMF3_OBJECT_MARKER )
      if doRef && handleReference( data, @storedObjects )
        return
      end

      writeAMF3Int( 0xB )
      @className2TraitsInfo[ data.hash ] = Hash.new
      writeAMF3String( '' )
      data.marshal_dump.each do |key, value|
        writeAMF3String( key.to_s )
        writeAMF3Data( value )
      end
      writeByte( AMF3_NULL_MARKER )
    end

    def writeAMF3Number( number )
      # can only handle signed 29bit ints
      if number >= -2^28 or number <= 2^28
        writeByte( AMF3_INTEGER_MARKER )
        writeAMF3Int( number )
      else
        writeByte( AMF3_DOUBLE_MARKER )
        writeDouble( number )
      end
    end

    def handleReference( obj, reference )
      key = false
      hash = obj.hash.to_s
      if reference[ hash ].nil?
        if reference.keys.count <= AMF_MAX_STORED_OBJECTS
          reference[ hash ] = reference.keys.count
        end
      else
        key = reference[ hash ]
      end

      if key
        if @amfVersion == AMF0_VERSION
          raise "unsupported AMF0_VERSION reference"
        else
          handle = key << 1
          writeAMF3Int( handle )
          return true
        end
      else
        return false
      end
    end

    def resetReferences
      @storedObjects          = Hash.new
      @storedStrings          = Hash.new
      @className2TraitsInfo   = Hash.new
    end
  end
end
