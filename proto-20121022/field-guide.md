
# Draft Field Guide to SDMX-JSON Objects

Use this guide to better understand SDMX-JSON objects.

- [Message](#Message)
- [Measure](#Measure)
- [Dimension](#Dimension)
- [Attribute](#Attribute)
- [Code](#Code)

Consumers of SDMX-JSON should tolerate the addition of new fields and variance
in ordering of fields with ease. Not all fields appear in all contexts. It is
generally safe to consider a nulled field, an empty set, and the absence of a
field as the same thing.

----

## <a name="Message"></a>Message

Message is the response you get back from the RESTful API. Message is the top
level object and it contains dimensions, attributes, observations and other
fields. Example:

    {
      "name": "Short-term interest rates: Day-to-day money rates",
      "id": "TEC00034",
      "test": false,
      "prepared": "2012-05-04T03:30:00.000Z",
      "measure": {
        # fields for measures #
      },
      "dimension": {
        # fields for dimensions #
      },
      "attribute": {
        # fields for attributes #
      },
      "error": null
    }

### name

*String* *nullable*. Brief summary of the message contents. Example:

    "name": "Short-term interest rates: Day-to-day money rates"

### id 

*String*. Unique string that identifies the message for further reference.
Example:

    "id": "TEC00034"

### test

*Boolean*. Test indicates whether the message is for test purposes or not. False
for normal messages. Example:

    "test": false

### prepared

*String*. Prepared is the date the message was prepared. String representation 
of Date formatted according to the ISO-8601 standard. Example

    "prepared": "2012-05-04T03:30:00.000Z"

### measure

*[Measure](#Measure)* *nullable*. Contains measures with observation values. Normal 
message contains only one measure but there can be multiple measures or no 
measures. Example:

    "measure": {
      "id": [
        "OBS_VALUE"
      ],
      "OBS_VALUE": {
        "name": "Observation value",
        "value": [
          2.9,
          3.64,
          2.39,
          1.96
        ],
        "size": 4
      }
    }
 
### dimension

*[Dimension](#Dimension)* *nullable*. Contains dimensions related to measures and
attributes in the message. Example:

    "dimension": {
        "id": [
          "ADJUSTMENT"
        ],
        "ADJUSTMENT": {
            "name": "Adjustment indicator",
            "role": null,
            "code": {
              "id": [
                "N"
              ],
              "index": {
                "N": 0
              },
              "name": {
                "N": "Neither seasonally or working day adjusted"
              },
              "size": 1
            }
        } 
    }

### attribute

*[Attribute](#Attribute)* *nullable*. Contains attributes that provide information about
the observation values. Example:

    attribute: {
      "id": [
        "OBS_COM",
        "UNIT_MULT"
      ],
      "OBS_COM": {
        "dimension": [
          "FREQ",
          "REF_AREA",
          "ADJUSTMENT",
          "ICP_ITEM",
          "STS_INSTITUTION",
          "ICP_SUFFIX",
          "TIME_PERIOD"
        ],
        "name": "Observation comment",
        "role": "attribute",
        "code": null,
        "value": {
          "262596": "Sharp decline due to abolition of Radio and TV license fees.",
          "263544": "Partial abolition of the tuition for 16 and 17 year old students",
          "266230": "Large insurance company changed prices for car insurance products"
        },
        "mandatory": false,
        "default": null,
        "size": 349180
      },
      "UNIT_MULT": {
        "dimension": [
          "REF_AREA",
          "ADJUSTMENT",
          "ICP_ITEM",
          "STS_INSTITUTION",
          "ICP_SUFFIX"
        ],
        "name": "Unit multiplier",
        "mandatory": true,
        "role": "attribute",
        "code": {
          "id": [
            "0"
          ],
          "index": {
            "0": 0
          },
          "name": {
            "0": "Units"
          },
          "size": 1
        },
        "default": "0",
        "size": 2210,
        "value": []
      }
    }

### error

*Array* *nullable*. RESTful web services indicates errors using the HTTP status
codes. In addition, whenever appropriate, the error is also be returned using 
the error fields. Error is an array of error messages. If there are no errors
then error is null. Example:

    "error": [
      "Invalid number of dimensions in parameter key"
    ] 

----

## <a name="Measure"></a>Measure

Measure is the container for measures with observation values. It contains fields
common to all measures and individual measures with measure specific fields. 
Measures are indentified with a id. Measure id is also the field name for the 
measure. Example:

    "measure": {
      "id": [
        "OBS_VALUE",
        "GROWTH_RATE"
      ],
      "OBS_VALUE": {
        # fields for measure OBS_VALUE #
      },
      "GROWTH_RATE": {
        # fields for measure GROWTH_RATE #        
      },
      "size": 2210
    }


### id (measure collection)

*Array*. An array of ids for all measures in message. Example:

    "id": [
      "OBS_VALUE"
    ]

### name

*String* *nullable*. Name provides for a human-readable name for the object.
Example:

    "name": "Observation value"

### value

*Array*. Array containing observation values. The data type for
observation value is *Number*. Undefined observation value is *null*. Data type
for a missing observation value is a *String* with the value "-". Example:

    value: [
      86.7,
      86.9,
      87.2,
      null,
      87.1,
      null,
      "-"
    ]

### size (measure collection)

*Number*. The size of the value arrays. All measures in the message have same
size. Size may be larger than thelength of the value array because nulls may be
trimmed from the end of the array. As a special case an empty message that
contains no observations has an empty value array (all observations are null)
and the size is the theoretical size of message. Example:

    "size": 349180

----

## <a name="Dimension"></a>Dimension

Dimension is a container for all dimensions in the message. It contains fields
common to all dimensions and the indidual dimensions. Dimensions have a common 
structure. Example:

    "dimension": {
      "id": [
        "FREQ",
        "REF_AREA",
        "ADJUSTMENT"
      ],
      "FREQ": {
        # fields for dimension FREQ #
      },
      "REF_AREA": {
        # fields for dimension REF_AREA #        
      },
      "ADJUSTMENT": {
        # fields for dimension ADJUSTMENT #        
      },      
      "size": 3
    }


### id (dimension collection)

*Array*. An array of with identifiers all dimensions in the message. The order of
dimensions in the array is significant. Example:

    "id": [
      "FREQ",
      "REF_AREA",
      "ADJUSTMENT",
      "ICP_ITEM",
      "STS_INSTITUTION",
      "ICP_SUFFIX",
      "TIME_PERIOD"
    ]

### size (dimension collection)

*Number*. The number of dimensions in the message. Same as the length of the id
array. Example:

    "size": 7

### name

*String* *nullable*. Name provides for a human-readable name for the object.
Example:

    "name": "Reference area"

### role

*String* *nullable*. Defines a role the dimension serves. Example:

    "role": "time"

### code

*[Code](#Code)*. Collection of codes for the dimension. Example:

    "code": {
      "id": [
        "M"
      ],
      "index": {
        "M": 0
      },
      "name": {
        "M": "Monthly"
      },
      "size": 1
    }

---

## <a name="Attribute"></a>Attribute

Attribute is the container for attributes in the message. Like other containers
it contains fields common to all attributes and individual attributes. All
attributes are identified with an id.

    "attribute": {
      "id": [
        "COLLECTION",
        "DECIMALS",
        "OBS_STATUS"
      ],
      "COLLECTION": {
        # fields for attribute COLLECTION #
      },
      "DECIMALS": {
        # fields for attribute DECIMALS #        
      },
      "OBS_STATUS": {
        # fields for attribute OBS_STATUS #        
      }
    }


### id (attribute collection)

*Array*. An array of with identifiers all attributes in message. Example:

    "id": [
      "COLLECTION",
      "COMPILATION",
      "DECIMALS",
      "DOM_SER_IDS",
      "PUBL_MU",
      "PUBL_PUBLIC",
      "TIME_FORMAT",
      "TITLE_COMPL",
      "UNIT",
      "UNIT_INDEX_BASE",
      "UNIT_MULT",
      "OBS_COM",
      "OBS_CONF",
      "OBS_STATUS"
    ]

### name

*String* *nullable*. Name provides for a human-readable name for the object.
Example:

    "name": "Observation status"

### dimension

*Array* *nullable*. Array of dimension ids for the attribute. Attribute can be 
attached to any combination of dimensions. Observation level attribute is 
attached to all dimensions in the message. Message level attribute is not
attached to any attributes and the dimension value is null. Attributes 
attached to other levels have varying number of dimensions. Example: 

    "dimension": [
      "FREQ",
      "REF_AREA",
      "ADJUSTMENT",
      "ICP_ITEM",
      "STS_INSTITUTION",
      "ICP_SUFFIX"
    ]

### mandatory

*Boolean*. Indicates whether a value must be provided for the attribute. Example:

    "mandatory": false

### role

*String* *nullable*. Defines a role the attribute serves. Example

    "role": "decimals"

### code

*[Code](#Code)* *nullable*. Collection of codes for the attribute. Null if the 
attribute is not coded. Example:

    "code": {
      "id": [
        "A",
        "E",
        "M",
        "P"
      ],
      "index": {
        "A": 0,
        "E": 1,
        "M": 2,
        "P": 3
      },
      "name": {
        "A": "Normal value",
        "E": "Estimated value",
        "M": "Missing value; data cannot exist",
        "P": "Provisional value"
      },
      "size": 4
    }

### default

*String* or *Number* *nullable*. Defines a default value for the attribute. If
no value is provided then this value applies. Example:

    "default": "A"

### value

*Array* or *Object*. Collection of attribute values. Values can be *String*, *Number*
or *null*. If value is an *Object* then the object keys equivalent to the index
values in an *Array*. Example:

    "value": {
      "262596": "Sharp decline due to abolition of Radio and TV license fees.",
      "263544": "Partial abolition of the tuition for 16 and 17 year old students",
      "266230": "Large insurance company changed prices for car insurance products"
    }

*String*. If the attribute does not have dimensions (dimension field is null) then
the value is a string. Example:

    "value": "Harmonised indices of consumer prices"

### size

*Number* *nullable*. The theoretical size of the value array for the attribute. 
The actual size of the value array can be smaller. If the attribute does not have
dimensions then the value is null. Example:

    "size": 349180

----

## <a name="Code"></a>Code

Code is the container of codes for dimensions and coded attributes. Code
contains collections of ids, indices, names and other information for individual
codes. It also contains the total number of codes. 

### id

*Array*. Identifiers for individual codes. The order of the codes is significant.
Example:

    "id": [
      "A",
      "E",
      "M",
      "P"
    ]

### index

*Object*. Collection of array indices for the codes. Index is always same as the
code index in the id array. Example:

    "index": {
      "A": 0,
      "E": 1,
      "M": 2,
      "P": 3
    }

### name

*Object*. Collection of human-readable names for codes. Example:

    "name": {
      "A": "Normal value",
      "E": "Estimated value",
      "M": "Missing value; data cannot exist",
      "P": "Provisional value"
    }

### size

*Number*. Totsl number of codes. Same as the length of the id array. Example:

    "size": 4

### parent

*Object* *nullable*. Collection of parent codes for code hierarchies. If the 
code is not in the collection then it does not belong to any hierarchy. Hierarchy
root codes have special value "ROOT" for the parent. There may be multiple
roots. Each code has only one parent. Example:

    "parent": {
      "AT": "U2",
      "BE": "U2",
      "CY": "U2",
      "DE": "U2",
      "ES": "U2",
      "FI": "U2",
      "FR": "U2",
      "GR": "U2",
      "IE": "U2",
      "IT": "U2",
      "LU": "U2",
      "MT": "U2",
      "NL": "U2",
      "PT": "U2",
      "SI": "U2",
      "SK": "U2",
      "U2": "ROOT"
    }

### start

*Object* *nullable*. Collection of start dates for codes in a time dimension.
This field is useful only when the codes are time periods for a time dimension
(dimension role is 'time'). Value is date in ISO format for the beginning of the 
period. Example:

    "start": {
      "2007-02": "2007-02-01T00:00:00.000Z",
      "2007-09": "2007-09-01T00:00:00.000Z",
      "2008-04": "2008-04-01T00:00:00.000Z",
      "2008-10": "2008-10-01T00:00:00.000Z",
      "2007-03": "2007-03-01T00:00:00.000Z",
      "2008-05": "2008-05-01T00:00:00.000Z",
      "2008-11": "2008-11-01T00:00:00.000Z",
      "2007-04": "2007-04-01T00:00:00.000Z"
    }

### end 

*Object* *nullable*. Collection of end dates for codes in a time dimension.
This field is useful only when the codes are time periods for a time dimension
(dimension role is 'time'). Value is date in ISO format for the end of the 
period. Example:

    "end": {
      "2007-10": "2007-10-31T23:59:59.000Z",
      "2008-06": "2008-06-30T23:59:59.000Z",
      "2008-12": "2008-12-31T23:59:59.000Z",
      "2007-05": "2007-05-31T23:59:59.000Z",
      "2007-11": "2007-11-30T23:59:59.000Z",
      "2008-07": "2008-07-31T23:59:59.000Z",
      "2007-06": "2007-06-30T23:59:59.000Z",
      "2007-12": "2007-12-31T23:59:59.000Z",
      "2008-01": "2008-01-31T23:59:59.000Z"
    }
