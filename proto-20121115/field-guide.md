
# Draft Field Guide to SDMX-PROTO-JSON Objects

**Version 2012-11-15**

Use this guide to better understand SDMX-PROTO-JSON objects.

- [Message](#Message)
- [Data](#Data)
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
      "sdmx-proto-json": "2012-11-15",
      "name": "Short-term interest rates: Day-to-day money rates",
      "id": "TEC00034",
      "test": false,
      "prepared": "2012-05-04T03:30:00.000Z",
      "data": [
        # data objects #
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

    "sdmx-proto-json": "2012-11-15"

### id

*String*. Unique string that identifies the message for further reference.
Example:

    "id": "TEC00034"

### name

*String* *nullable*. Brief summary of the message contents. Example:

    "name": "Short-term interest rates: Day-to-day money rates"

### test

*Boolean*. Test indicates whether the message is for test purposes or not. False
for normal messages. Example:

    "test": false

### prepared

*String*. Prepared is the date the message was prepared. String representation
of Date formatted according to the ISO-8601 standard. Example:

    "prepared": "2012-05-04T03:30:00.000Z"

### data

*Array* *nullable*. *Data* field is an array of *[Data](#Data)* objects. Example:

    "data": [
      {
        "dimensions": [ 0, 0 ],
        "observations": [
          [ 0, 2.9 ],
          [ 1, 3.64 ]
        ]
      },
      {
        "dimensions": [ 0, 1 ],
        "observations": [
          [ 0, 5.52 ],
          [ 1, 4.1 ],
          [ 2, 2.45 ]
        ]
      }
    ]

### dimensions

*[Dimensions](#Dimensions)* *nullable*. Contains dimensions identifying the measure
and attribute values. Example:

    "dimensions": {
      "id": [
        "ADJUSTMENT"
      ],
      "dimensionAtObservation": "AllDimensions",
      "ADJUSTMENT": {
        "id": "ADJUSTMENT",
        "name": "Adjustment indicator",
        "type": null,
        "codes": [
          {
            "id": "N",
            "name": "Neither seasonally or working day adjusted",
            "index": 0,
            "order": 0
          }
        ]
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
      "obsAttributes": [
        "OBS_COM"
      ],
      "OBS_COM": {
        "id": "OBS_COM",
        "name": "Observation comment",
        "code": null,
        "mandatory": false,
        "default": null
      },
      "UNIT_MULT": {
        "id": "UNIT_MULT",
        "name": "Unit multiplier",
        "mandatory": true,
        "codes": {
          "id": [
            "0"
          ],
          "0": {
            "id": "0",
            "name": "Units",
            "index": 0,
            "order": 0
          }
        },
        "default": "0"
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

## <a name="Data"></a>Data

Data object is a container for the data and reference metadata. Data object
contains either an observation field or an attributes field or both. It normally
contains also a dimensions field. Example:

    {
      "dimensions": [ 0, 0, 0, 0, 0, 0 ],
      "attributes": {
        "TIME_FORMAT": "P1M",
        "COLLECTION": "A",
        "UNIT_INDEX_BASE": "2005 = 100",
        "DOM_SER_IDS": "Eurostat code: VAL.IDX05.AUT.00",
        "PUBL_PUBLIC": "SPB.T1101",
        "PUBL_MU": "ORB.T040104; ORB.T061200"
      },
      "observations": [
        [ 0, 105.6 ],
        [ 1, 105.9 ],
        [ 2, 106.9 ],
        [ 3, 107.3, "P" ]
      ]
    }

### dimensions

*Array* *nullable*. An array of dimension codes. Each code is an index to the
*codes* array in the respective *Dimension* object. If the code is *null* then
code value for respective dimension is undefined. For example if the data object
is a sibling set. If dimensions is null then values for all dimensions are null.
For example if the data object is data set level attributes. Example:

    // Dimensions for time series
    "dimensions": [
      0,
      93,
      12,
      1
    ]

    // Dimensions for sibling set
    "dimensions": [
      null,
      93,
      12,
      1
    ]

### attributes

*Object* *nullable*. Collection of attributes values. Field names are attributes
ids and field values are attribute values. Example:

    "attributes": {
      "TIME_FORMAT": "P1M",
      "COLLECTION": "A",
      "UNIT_INDEX_BASE": "2005 = 100"
    }


### observations

*Array* *nullable*. An array of observation values. Each observation value is an
array of two of more values.

Array begins with dimension codes. Then number of dimension codes depends on t
he value of the *dimensionAtObservation* field in  the *dimensions* object. If
the value is *AllDimensions* then there is array element of each dimension. If
the value is not *AllDimensions* then there is  only one dimension code.

    // dimensionAtObservation is 'AllDimensions' with four dimensions

    {
      "observations": [
        [ 0, 0, 0, 0, 86.7 ],
        [ 0, 0, 0, 1, 86.9 ],
    },
    {
      "observations": [
        [ 0, 0, 1, 0, 87.2 ],
        [ 0, 0, 1, 1, "-", "M" ]
      ]
    }

    // dimensionAtObservation is 'TIME_PERIOD' with four dimensions

    {
      "dimensions": [ 0, 0, 0 ],
      "observations": [
        [ 0, 86.7 ],
        [ 1, 86.9 ],
    },
    {
      "dimensions": [ 0, 0, 1 ],
      "observations": [
        [ 0, 87.2 ],
        [ 1, "-", "M" ]
      ]
    }

Next element after the dimension codes is the observation value. The data type
for observation value is *Number*. Undefined observation value is
*null*. Data type for a missing observation value is a *String* with the value
"-" (HYPHEN).

Elements after the observation value are values for the observation level attributes.
Observation level attributes are defined in the *obsAttributes* field in the
*attributes* object. Nulls may be trimmed from the end of the array.

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

### dimensionAtObservation (dimensions collection)

*String*. The id of the dimension that is "at observation".
*dimensionAtObservation* provides a way to group data values in *measure* field
by any dimension in the *dimensions* collection. If the value is "AllDimensions"
then the measure field is not grouped and it is a flat array or object. Example:

    "dimensionAtObservation": "TIME_PERIOD"

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

### codes

*[Codes](#Codes)*. Array of codes for the dimension. Example:

    "codes": [
      {
        "id": "M",
        "name": "Monthly",
        "index": 0,
        "order": 0
      }
    ]

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

### obsAttributes

*Array*. An array of observation level attribute identifiers. Example:

    "obsAttributes": [
      "OBS_STATUS",
      "OBS_CONF",
      "OBS_COM"
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

### mandatory

*Boolean*. Indicates whether a value must be provided for the attribute. Example:

    "mandatory": false

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
        "index": 0,
        "order": 0
      },
      "E": {
        "id": "E",
        "name": "Estimated value",
        "index": 1,
        "order": 1
      },
      "M": {
        "id": "M",
        "name": "Missing value; data cannot exist",
        "index": 2,
        "order": 2
      },
      "A": {
        "id": "P",
        "name": "Provisional value",
        "index": 3,
        "order": 3
      }
    }

### default

*String* or *Number* *nullable*. Defines a default value for the attribute. If
no value is provided then this value applies. Example:

    "default": "A"

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

*Number*. Array index for a code. Index is always same as the
code index in the id array. Example:

    "index": 0

### order

*Number*. Default display order for the code. Example:

    "order": 64

### parent

*String* *nullable*. Parent codes for code hierarchies. If parent is null then
the code does not belong to any hierarchy. Hierarchy root codes have special
value "ROOT" for the parent. There may be multiple roots. Each code has only one
parent. Example:

    "parent": "U2"

### start

*String* *nullable*. Start date for a code in a time dimension.
This field is useful only when the codes are time periods for a time dimension
(dimension type is 'time'). Value is date in ISO format for the beginning of the
period. Example:

    "start": "2007-02-01T00:00:00.000Z"

### end

*String* *nullable*. End date for a code in a time dimension.
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
