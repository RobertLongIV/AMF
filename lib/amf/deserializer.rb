module AMF
  class Deserializer
    require 'stringio'
    require 'ostruct'
    require 'amf/constants'
    require 'amf/header'
    require 'amf/message'

    attr_reader :headers, :messages, :version

    def initialize( data )
      if StringIO == data.class
        @data = data
      else
        @data = StringIO.new data
      end
      readHeaders
      readMessages

      resetReferences
      @data = nil
    end

    def serialize
      AMF::Serializer.new( headers, messages, version ).data
    end

    # make this work a little bit more like a ruby object
    def to_hash
      {
          'version' => self.version,
          'headers' => self.headers.map{ |h| h.to_hash },
          'messages' => self.messages.map{ |m| m.to_hash },
      }
    end

    private

    def readHeaders
      @headers = Array.new
      if ! [0,3].include? readByte
          raise "Data is not in expected format"
      end

      # throw away the next byte, flash version which we're ignoring
      readByte

      # we have Int headers, process them all
      readInt.times do
        resetReferences
        name = readUTF
        required = readByte == 1
        length = readLong # throwaway
        type = readByte
        content = readData( type )

        @headers << AMF::Header.new( name, required, content )
      end
    end

    def readMessages
      @messages = Array.new
      readInt.times do
        resetReferences
        target = readUTF
        response = readUTF
        length = readLong # throwaway
        type = readByte
        data = readData( type )

        @messages << AMF::Message.new( target, response, data )
      end
    end

    def readData( type )
      case type
        when AMF0_AMF3_MARKER
          readAMF3Data
        when AMF0_NUMBER_MARKER
          readDouble
        when AMF0_BOOLEAN_MARKER
          readByte == 1
        when AMF0_STRING_MARKER
          readUTF
        when AMF0_OBJECT_MARKER
          raise 'Unsupported type AMF0_OBJECT_MARKER'
        when AMF0_MOVIE_CLIP_MARKER
          raise 'Unsupported type AMF0_MOVIE_CLIP_MARKER'
        when AMF0_NULL_MARKER
          nil
        when AMF0_UNDEFINED_MARKER
          nil
        when AMF0_REFERENCE_MARKER
          raise 'Unsupported type AMF0_REFERENCE_MARKER'
        when AMF0_HASH_MARKER
          raise 'Unsupported type AMF0_HASH_MARKER'
        when AMF0_OBJECT_END_MARKER
          raise 'Unsupported type AMF0_OBJECT_END_MARKER'
        when AMF0_STRICT_ARRAY_MARKER
          raise 'Unsupported type AMF0_STRICT_ARRAY_MARKER'
        when AMF0_DATE_MARKER
          raise 'Unsupported type AMF0_DATE_MARKER'
        when AMF0_LONG_STRING_MARKER
          raise 'Unsupported type AMF0_LONG_STRING_MARKER'
        when AMF0_UNSUPPORTED_MARKER
          nil
        when AMF0_RECORDSET_MARKER
          raise 'Unsupported type AMF0_RECORDSET_MARKER'
        when AMF0_XML_MARKER
          raise 'Unsupported type AMF0_XML_MARKER'
        when AMF0_TYPED_OBJECT_MARKER
          raise 'Unsupported type AMF0_TYPED_OBJECT_MARKER'
        else
          raise "Unsupported AMF0 type: #{ type }"
        end
    end

    def readAMF3Data
      @version = AMF3_VERSION

      type = readByte
      case type
        when AMF3_UNDEFINED_MARKER
          nil
        when AMF3_NULL_MARKER
          nil
        when AMF3_FALSE_MARKER
          false
        when AMF3_TRUE_MARKER
          true
        when AMF3_INTEGER_MARKER
          readAMF3Int
        when AMF3_DOUBLE_MARKER
          readDouble
        when AMF3_STRING_MARKER
          readAMF3String
        when AMF3_XML_DOC_MARKER
          raise 'Unsupported type AMF3_XML_DOC_MARKER'
        when AMF3_DATE_MARKER
          readAMF3Date
        when AMF3_ARRAY_MARKER
          readAMF3Array
        when AMF3_OBJECT_MARKER
          readAMF3Object
        when AMF3_XML_MARKER
          raise 'Unsupported type AMF3_XML_MARKER'
        when AMF3_BYTE_ARRAY_MARKER
          raise 'Unsupported type AMF3_BYTE_ARRAY_MARKER'
        when AMF3_DICT_MARKER
          raise 'Unsupported type AMF3_DICT_MARKER'
        else
          raise "Unsported AMF3 type: #{ type }"
      end
    end

    def readByte
      @data.readchar.unpack("C")[0]
    end

    def readInt
      ( readByte << 8 ) + readByte
    end

  def readUTF
      length = readInt
      if length == 0
        ''
      else
        string = String.new
        length.times do
          string << readByte.chr
        end
      end
      string
    end

    def readAMF3Int
      int = readByte
      if int < 128
        int
      else
        int = ( int & 127 ) << 7
        next_int = readByte
        if next_int < 128
          int | next_int
        else
          int = ( int | ( next_int & 127 ) ) << 7
          next_int = readByte
          if next_int < 128
            int | next_int
          else
            int = ( int | ( next_int & 127 ) ) << 8
            int |= readByte

            # We have 29bit ints in AMF3, need to convert those to something
            # more normalized
            if int & 0x10000000 != 0
              int |= ~0x1fffffff
            end
            int
          end
        end
      end
    end

    def readDouble
      bytes = String.new
      8.times do
        bytes << readByte
      end
      bytes.to_s.reverse.unpack( 'dbfl' )[0]
    end

    def readLong
      ( readByte << 24 ) | ( readByte << 16 ) | ( readByte << 8 ) | readByte
    end

    def readAMF3String
      strref = readAMF3Int

      if ( strref & 1 ) == 0
        strref = strref >> 1
        if @storedStrings[ strref ].nil?
          raise "found a undefined string ref: #{ strref }"
        end
        @storedStrings[ strref ]
      else
        strlen = strref >> 1
        str = String.new
        if strlen > 0
          @storedStrings << readBuffer( strlen )
          @storedStrings.last
        else
          ''
        end
      end
    end

    def readBuffer( length )
      data = String.new
      length.times do
        data << readByte.chr
      end
      data
    end

    def readAMF3Date
      firstInt = readAMF3Int
      if ( firstInt & 1 ) == 0
        firstInt = firstInt >> 1
        if @storedObjects[ firstInt ].nil?
          raise "found an undeifned storedObject ref: #{ firstInt }"
        end
        @storedObjects[ firstInt ]
      else
        ms = readDouble
        @storedObjects << Time.at( ms )
        Time.at ms
      end
    end

    def readAMF3Array
      handle = readAMF3Int
      inline = ( handle & 1 ) != 0
      handle = handle >> 1
      if inline
        storeable = Hash.new
        @storedObjects << storeable
        key = readAMF3String
        while key != ''
          storeable[ key ] = readAMF3Data
          key = readAMF3String
        end

        handle.times do |i|
          storeable[ i ] = readAMF3Data
        end

        storeable
      else
        @storedObjects[ handle ]
      end
    end

    # uhhggg, this one sucks!
    def readAMF3Object
      handle = readAMF3Int
      inline = ( handle & 1 ) != 0
      handle = handle >> 1

      if ! inline
        return @storedObjects[ handle ]
      end

      inlineClassDef = ( handle &1 ) != 0
      handle = handle >> 1
      if inlineClassDef
        typeId = readAMF3String
        externalizable = ( handle &1 ) != 0
        handle = handle >> 1
        dynamic = ( handle &1 ) !=0
        handle = handle >> 1
        classMemberCount = handle

        classMemberDefinitions = Array.new
        classMemberCount.times do
          classMemberDefinitions << readAMF3String
        end

        classDefinition = {
                  'type'              => typeId,
                  'externalizable'    => externalizable,
                  'dynamic'           => dynamic,
                  'members'           => classMemberDefinitions
        }
        @storedDefinitions << classDefinition
      else
        classDefinition = @storedDefinitions[ handle ]
      end

      obj = OpenStruct.new
      @storedObjects << obj

      if classDefinition[ 'externalizable' ]
        obj.send( "#{ AMF_FIELD_EXTERNALIZED_DATA }=", readAMF3Data )
      else
        classDefinition[ 'members' ].each do |member|
          obj.send( "#{ member }=", readAMF3Data )
        end

        if classDefinition[ 'dynamic' ]
          key = readAMF3String
          while key != ''
            obj.send( "#{ key }=", readAMF3Data )
            key = readAMF3String
          end
        end
      end

      if classDefinition[ 'type' ] != ''
        obj.send( "#{ AMF_FIELD_EXPLICIT_TYPE }=", classDefinition[ 'type' ] )
      end

      obj
    end

    def resetReferences
      @storedStrings      = Array.new
      @storedObjects      = Array.new
      @storedDefinitions  = Array.new
    end
  end
end

