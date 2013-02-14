
# Draft Field Guide to SDMX-PROTO-JSON Objects

**Version for jsonarray format**

Use this guide to better understand SDMX-PROTO-JSON objects.

- [Message](#Message)
- [Dimensions](#Dimensions)
- [Attributes](#Attributes)
- [Codes](#Codes)

New fields may be introduced in later versions of the field guide. Therefore
consuming applications should tolerate the addition of new fields with ease.

The ordering of fields in objects is undefined. The fields may appear in any order
and consuming applications should not rely on any specific ordering. It is safe
to consider a nulled field and the absence of a field as the same thing.

Not all fields appear in all contexts. For example response with error messages
may not contain fields for measure, dimension and attributes.

----

## <a name="Message"></a>Message

Message is the response you get back from the RESTful API. Message is the top
level object and it contains dimensions, attributes and other
fields. Example:

    {
      "sdmx-proto-json": "2013-01-03",
      "name": "BIS Effective Exchange Rates",
      "id": "6e02ecae-522f-4a76-b861-b2c07b38b3dd",
      "prepared": "2013-01-03T12:57:58",
      "measure": [
        [
          2.9,
          3.64,
          2.39,
          1.96
        ]
      ],
      "dimensions": {
        # fields for dimensions #
      },
      "attributes": {
        # fields for attributes #
      },
      "errors": null
    }

### sdmx-proto-json

*String*. A string specifying the version of the SDMX-PROTO-JSON response.
Version string is the same as the version of the field guide. Example:

    "sdmx-proto-json": "2012-09-13"

### id

*String*. Unique string that identifies the message for further reference.
Example:

    "id": "TEC00034"

### name

*String* *nullable*. Brief summary of the message contents. Example:

    "name": "Short-term interest rates: Day-to-day money rates"

### test

*Boolean* *nullable*. Test indicates whether the message is for test purposes or not. False
for normal messages. Example:

    "test": false

### prepared

*String*. Prepared is the date the message was prepared. String representation
of Date formatted according to the ISO-8601 standard. Example:

    "prepared": "2012-05-04T03:30:00"

### measure

*Array*. *Measure* field contains data values. The
data type for observation value is *Number*. Undefined observation value is
*null*. Data type for a missing observation value is a *String* with the value
"-" (HYPHEN). Example:

    "measure": [
      [
        86.7,
        86.9,
        87.2,
        null,
        87.1,
        null,
        "-"
      ]
    ]


### dimensions

*[Dimensions](#Dimensions)* *nullable*. Contains dimensions identifying the measure
and attribute values. Example:

    "dimensions": {
      "id": [
        "ADJUSTMENT"
      ],
      "size": [
        1
      ],
      "dimensionAtObservation": "AllDimensions",
      "ADJUSTMENT": {
        "id": "ADJUSTMENT",
        "name": "Adjustment indicator",
        "type": null,
        "roles": null,
        "codes": {
          "id": [
            "N"
          ],
          "N": {
            "id": "N",
            "name": "Neither seasonally or working day adjusted",
            "index": 0
          }
        }
      }
    }

### attributes

*[Attributes](#Attributes)* *nullable*. Contains attributes that provide information about
the observation values. Example:

    attribute: {
      "id": [
        "OBS_COM",
        "UNIT_MULT"
      ],
      "OBS_COM": {
        "id": "OBS_COM",
        "name": "Observation comment",
        "dimension": [
          "FREQ",
          "REF_AREA",
          "ADJUSTMENT",
          "ICP_ITEM",
          "STS_INSTITUTION",
          "ICP_SUFFIX",
          "TIME_PERIOD"
        ],
        "roles": null,
        "code": null,
        "value": {
          "262596": "Sharp decline due to abolition of Radio and TV license fees.",
          "263544": "Partial abolition of the tuition for 16 and 17 year old students",
          "266230": "Large insurance company changed prices for car insurance products"
        },
        "mandatory": false,
        "default": null
      },
      "UNIT_MULT": {
        "id": "UNIT_MULT",
        "name": "Unit multiplier",
        "dimension": [
          "REF_AREA",
          "ADJUSTMENT",
          "ICP_ITEM",
          "STS_INSTITUTION",
          "ICP_SUFFIX"
        ],
        "mandatory": true,
        "roles": null,
        "codes": {
          "id": [
            "0"
          ],
          "0": {
            "id": "0",
            "name": "Units",
            index": 0
          }
        },
        "default": "0"
        "value": []
      }
    }

### errors

*Array* *nullable*. RESTful web services indicates errors using the HTTP status
codes. In addition, whenever appropriate, the error is also be returned using
the error fields. Error is an array of error messages. If there are no errors
then error is null. Example:

    "errors": [
      "Invalid number of dimensions in parameter key"
    ]

----

## <a name="Dimensions"></a>Dimensions

Dimension is a container for all dimensions in the message. It contains fields
common to all dimensions and the individual dimensions. Dimensions share a common
structure. Example:

    "dimensions": {
      "id": [
        "FREQ",
        "REF_AREA",
        "ADJUSTMENT"
      ],
      "size": [
        3,
        6,
        2
      ],
      "FREQ": {
        # fields for dimension FREQ #
      },
      "REF_AREA": {
        # fields for dimension REF_AREA #
      },
      "ADJUSTMENT": {
        # fields for dimension ADJUSTMENT #
      }
    }


### id (dimensions collection)

*Array*. An array of with identifiers all dimensions in the message. The order of
dimensions in the array is significant. (Note that in the current prototype the
TIME_PERIOD dimension is erroneosly missing from the array). Example:

    "id": [
      "FREQ",
      "REF_AREA",
      "ADJUSTMENT",
      "ICP_ITEM",
      "STS_INSTITUTION",
      "ICP_SUFFIX",
      "TIME_PERIOD"
    ]

### size (dimensions collection)

*Array*. The number of codes for each dimensions in the message. Example:

    "size": [
      3,
      29,
      23
    ]

### id

*String*. Identifier for the dimension.
Example:

    "id": "FREQ"

### name

*String*. Name provides for a human-readable name for the object.
Example:

    "name": "Frequency"

### description

*String* *nullable*. Provides as description for the object. Example:

    "description": "The time interval at which observations occur over a given time period."

### type

*String* *nullable*. Defines the dimension type. For normal dimensions the value
is null. There are two special dimension types:

- **time**. Time dimension is a special dimension which designates the period in
time in which the data identified by the full series key applies.
- **measure**. Measure dimension is a special type of dimension which defines
multiple measures.

Example:

    "type": "time"

### roles

*Array* *nullable*. Defines roles the dimension serves. Example:

    "roles": [ "GEO" ]

### codes

*[Codes](#Codes)*. Collection of codes for the dimension. Example:

    "codes": {
      "id": [
        "M"
      ],
      "M": {
        "id": "M",
        "name": "Monthly",
        "index": 0
      }
    }

---

## <a name="Attributes"></a>Attributes

Attributes is the container for attributes in the message. Like other containers
it contains fields common to all attributes and individual attributes. All
attributes are identified with an id.

    "attributes": {
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

### id

*String*. Identifier for an attribute. Example:

    "id": "COLLECTION"

### name

*String*. Name provides for a human-readable name for the object.
Example:

    "name": "Observation status"

### description

*String* *nullable*. Provides a description for the object. Example:

    "description": "Information on the quality of a value or an unusual or missing value."

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

### roles

*Array* *nullable*. Defines roles the attribute serves. Example

    "roles": [
     "DECIMALS"
    ]

### codes

*[Codes](#Codes)* *nullable*. Collection of codes for the attribute. Null if the
attribute is not coded. Example:

    "codes": {
      "id": [
        "A",
        "E",
        "M",
        "P"
      ],
      "A": {
        "id": "A",
        "name": "Normal value",
        "index": 0
      },
      "E": {
        "id": "E",
        "name": "Estimated value",
        "index": 1
      },
      "M": {
        "id": "M",
        "name": "Missing value; data cannot exist",
        "index": 2
      },
      "A": {
        "id": "P",
        "name": "Provisional value",
        "index": 3
      }
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

----

## <a name="Codes"></a>Codes

Codes is the container of codes for dimensions and coded attributes. Code
contains collections of ids, indices, names and other information for individual
codes. It also contains the total number of codes. Example:

    "codes": {
      "id": [
        "A",
        "Q",
        "M"
      ]
      "A": {
        # Fields for code "A"
      },
      "Q": {
        # Fields for code "Q"
      },
      "M": {
        # Fields for code "M"
      }
    }

### id (codes collection)

*Array*. Identifiers for individual codes. The order of the codes is significant.
Example:

    "id": [
      "A",
      "E",
      "M",
      "P"
    ]

### id

*String*. Identifier for a code. Example:

    "id": "A"

### name

*String*. Human-readable names for a code. Example:

    "name": "Missing value; data cannot exist"

### description

*String* *nullable*. Description provides a plain text, human-readable
description of the code. Example:

    "description": "Provisional value"

### index

*Object*. Array index for a code. Index is always same as the
code index in the id array. Example:

    "index": 0

### parent

*Object* *nullable*. Parent codes for code hierarchies. If parent is null then
the code does not belong to any hierarchy. Hierarchy root codes have special
value "ROOT" for the parent. There may be multiple roots. Each code has only one
parent. Example:

    "parent": "U2"

### start

*Object* *nullable*. Start date for a code in a time dimension.
This field is useful only when the codes are time periods for a time dimension
(dimension type is 'time'). Value is date in ISO format for the beginning of the
period. Example:

    "start": "2007-02-01T00:00:00.000Z"

### end

*Object* *nullable*. End date for a code in a time dimension.
This field is useful only when the codes are time periods for a time dimension
(dimension type is 'time'). Value is date in ISO format for the end of the
period. Example:

    "end": "2007-10-31T23:59:59.000Z"

### geometry

*Object* *nullable*. Represents the geographic location of this code (country,
reference area etc.). The inner coordinates array is formatted as [geoJSON]
(http://www.geojson.org) (longitude first, then latitude). Example:

    "geometry": {
      "type": "Point",
      "coordinates": [
        62.4302,
        24.7271
      ]
    }
