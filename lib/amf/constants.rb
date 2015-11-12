module AMF
    # AMF0 Type Markers
    AMF0_NUMBER_MARKER          = 0
    AMF0_BOOLEAN_MARKER         = 1
    AMF0_STRING_MARKER          = 2
    AMF0_OBJECT_MARKER          = 3
    AMF0_MOVIE_CLIP_MARKER      = 4
    AMF0_NULL_MARKER            = 5
    AMF0_UNDEFINED_MARKER       = 6
    AMF0_REFERENCE_MARKER       = 7
    AMF0_HASH_MARKER            = 8
    AMF0_OBJECT_END_MARKER      = 9
    AMF0_STRICT_ARRAY_MARKER    = 10
    AMF0_DATE_MARKER            = 11
    AMF0_LONG_STRING_MARKER     = 12
    AMF0_UNSUPPORTED_MARKER     = 13
    AMF0_RECORDSET_MARKER       = 14
    AMF0_XML_MARKER             = 15
    AMF0_TYPED_OBJECT_MARKER    = 16
    AMF0_AMF3_MARKER            = 17

    # AMF3 Type Markers
    AMF3_UNDEFINED_MARKER       = 0
    AMF3_NULL_MARKER            = 1
    AMF3_FALSE_MARKER           = 2
    AMF3_TRUE_MARKER            = 3
    AMF3_INTEGER_MARKER         = 4
    AMF3_DOUBLE_MARKER          = 5
    AMF3_STRING_MARKER          = 6
    AMF3_XML_DOC_MARKER         = 7
    AMF3_DATE_MARKER            = 8
    AMF3_ARRAY_MARKER           = 9
    AMF3_OBJECT_MARKER          = 10
    AMF3_XML_MARKER             = 11
    AMF3_BYTE_ARRAY_MARKER      = 12
    AMF3_DICT_MARKER            = 13

    # Other AMF3 Markers
    AMF3_EMPTY_STRING           = 1
    AMF3_CLOSE_DYNAMIC_OBJECT   = 1
    AMF3_CLOSE_DYNAMIC_ARRAY    = 1
    AMF3_VERSION                = 3
    AMF0_VERSION                = 0
    AMF_MAX_STORED_OBJECTS      = 1024
    AMF_FIELD_EXPLICIT_TYPE     = '_explicitType'
    AMF_FIELD_EXTERNALIZED_DATA = '_externalizedData'
end

