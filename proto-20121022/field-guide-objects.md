
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
level object and it contains dimensions, attributes, measures and other
fields. Example:

    {
      "name": "Short-term interest rates: Day-to-day money rates",
      "id": "TEC00034",
      "test": false,
      "prepared": "2012-05-04T03:30:00.000Z",
      "measures": [
        # Measures #
      ],
      "dimensions": [
        # Dimensions #
      ],
      "attributes": [
        # Attributes #
      ],
      "errors": [
        # Error messages #
      ]
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

### measures

Collection of *[Measures](#Measure)* *nullable*. Contains measures with 
observation values. Normal message contains only one measure but there can be 
multiple measures or no measures. Example:

    "measures": [
      {
        "id": "OBS_VALUE"
        "name": "Observation value",
        "values": [
          2.9,
          3.64,
          2.39,
          1.96
        ]
      }
    ]
 
### dimensions

Collection of *[Dimensions](#Dimension)* *nullable*. Contains dimensions related
to measures and attributes in the message. Example:

    "dimensions": [
      {
        "id": "ADJUSTMENT",
        "name": "Adjustment indicator",
        "role": null,
        "codes": [
          {
            "id": "N",
            "name": Neither seasonally or working day adjusted"
          }
        ]
      }
    ]

### attributes

Collection of *[Attributes](#Attribute)* *nullable*. Contains attributes that 
provide information about the observation values. Example:

    attributes: [
      {
        "id": "OBS_COM",
        "dimensions": [
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
        "codes": null,
        "values": {
          "262596": "Sharp decline due to abolition of Radio and TV license fees.",
          "263544": "Partial abolition of the tuition for 16 and 17 year old students",
          "266230": "Large insurance company changed prices for car insurance products"
        },
        "mandatory": false,
        "default": null,
      },
      {
        "id": "UNIT_MULT",
        "dimensions": [
          "REF_AREA",
          "ADJUSTMENT",
          "ICP_ITEM",
          "STS_INSTITUTION",
          "ICP_SUFFIX"
        ],
        "name": "Unit multiplier",
        "mandatory": true,
        "role": "attribute",
        "codes": [
          {
            "id": "0",
            "name": "Units"
          }
        ],
        "default": "0",
        "values": []
      }
    ]

### errors

*Array* *nullable*. RESTful web services indicates errors using the HTTP status
codes. In addition, whenever appropriate, the error is also be returned using 
the error fields. Error is an array of error messages. If there are no errors
then error is null. Example:

    "errors": [
      "Invalid number of dimensions in parameter key"
    ] 

----

## <a name="Measure"></a>Measure

Measure is the container for observation values. Measures are indentified with 
an id. Example:

    {
      "id": "OBS_VALUE",
      "name": "Observation value",
      "values": [
        8475,
        null,
        946,
        "-",
        2747
      ]
    }

### id

*String*. An unique identifier for the measure. Example:

    "id": "OBS_VALUE"

### name

*String* *nullable*. Name provides for a human-readable name for the object.
Example:

    "name": "Observation value"

### values

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

----

## <a name="Dimension"></a>Dimension

Dimension describes the structure of a dimension, which is defined as a
statistical concept used (most probably together with other statistical
concepts) to identify a statistical series, such as a time series, e.g. a
statistical concept indicating certain economic activity or a geographical
reference area. Example:

    {
      "id": "FREQ",
      "name": "Frequency",
      "role": null,
      "codes": [
        {
          "id": "M",
          "name": "Monhtly"
        },
        {
          "id": "Q",
          "name": "Quarterly"
        }
      ]
    }


### id

*String*. An identifier for a dimension. Example:

    "id": "FREQ"

### name

*String* *nullable*. Name provides for a human-readable name for the object.
Example:

    "name": "Reference area"

### role

*String* *nullable*. Defines a role the dimension serves. Example:

    "role": "time"

### codes

Collection of *[Codes](#Code)*. Collection of codes for the dimension. Example:

    codes: [
      {
        "id": "M",
        "name": "Monhtly"
      },
      {
        "id": "Q",
        "name": "Quarterly"
      }
    ]

---

## <a name="Attribute"></a>Attribute

Attribute describes the definition of a data attribute, which is defined as a 
characteristic of an object or entity. All attributes are identified with an id.
Example:

    {
      "id": "COLLECTION",
      "dimensions": [
        "FREQ",
        "REF_AREA",
        "ADJUSTMENT",
        "ICP_ITEM",
        "STS_INSTITUTION",
        "ICP_SUFFIX"
      ],
      "name": "Collection indicator",
      "mandatory": true,
      "role": null,
      "codes": [
        {
          "id": "A",
          "name": "Average of observations through period"
        }
      ]
      "default": "A",
      "size": 2210,
      "values": []
    }


### id

*String*. An identifier for a attribute. Example:

    "id": "COLLECTION"

### name

*String* *nullable*. Name provides for a human-readable name for the object.
Example:

    "name": "Observation status"

### dimensions

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

### codes

Collection of *[Codes](#Code)* *nullable*. Collection of codes for the attribute. 
Null if the attribute is not coded. Example:

    "codes": [
      {
        "id": "A",
        "name": "Normal value"
      }
      {
        "id": "E",
        "name": "Estimated value"
      }
      {
        "id": "M",
        "name": "Missing value; data cannot exist"
      },
      {
        "id": "P",
        "name": "Provisional value"
      }
    ]

### default

*String* or *Number* *nullable*. Defines a default value for the attribute. If
no value is provided then this value applies. Example:

    "default": "A"

### values

*Array* or *Object*. Collection of attribute values. Values can be *String*, *Number*
or *null*. If value is an *Object* then the object keys equivalent to the index
values in an *Array*. Example:

    "values": {
      "262596": "Sharp decline due to abolition of Radio and TV license fees.",
      "263544": "Partial abolition of the tuition for 16 and 17 year old students",
      "266230": "Large insurance company changed prices for car insurance products"
    }

*String*. If the attribute does not have dimensions (dimension field is null) then
the value is a string. Example:

    "values": "Harmonised indices of consumer prices"

----

## <a name="Code"></a>Code

Code describes a code in a codelist. Example:

    {
      "id": "FI",
      "name": "Finland",
      "parent": "U2"
    }

### id

*String*. Identifier for a code. Example:

    "id": "EUR"

### name

*String*. Human-readable name for a code. Example:

    "name": "Missing value; data cannot exist"

### parent

*String* *nullable*. Parent codes for code hierarchies. Hierarchy
root codes have special value "ROOT" for the parent. Example:

    "parent": "U2"

### start

*String* *nullable*. Start dates for a code in a time dimension.
This field is useful only when the codes are time periods for a time dimension
(dimension role is 'time'). Value is date in ISO format for the beginning of the 
period. Example:

    "start": "2007-02-01T00:00:00.000Z"

### end 

*String* *nullable*. End date for a code in a time dimension.
This field is useful only when the codes are time periods for a time dimension
(dimension role is 'time'). Value is date in ISO format for the end of the 
period. Example:

    "end": "2007-10-31T23:59:59.000Z"

### geometry

*Object* *nullable*. Represents the geographic location of this code (country,
reference area etc.). The inner coordinates array is formatted as [geoJSON]
(http://www.geojson.org) (longitude first, then latitude). Example:

    "geometry": {
      "type":"Point",
      "coordinates": [
        62.4302,
        24.7271
      ]
    }
