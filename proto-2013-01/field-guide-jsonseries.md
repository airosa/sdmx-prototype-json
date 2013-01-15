# Draft Field Guide to SDMX-PROTO-JSON Objects

**Version for jsonseries format**

Use this guide to better understand SDMX-PROTO-JSON objects.

- [Introduction](#Introduction)
- [Message](#Message)
- [Header](#Header)
- [Data](#Data)
- [Dimensions](#Dimensions)
- [Attributes](#Attributes)
- [Code](#Code)

New fields may be introduced in later versions of the field guide. Therefore
consuming applications should tolerate the addition of new fields with ease.

The ordering of fields in objects is undefined. The fields may appear in any order
and consuming applications should not rely on any specific ordering. It is safe
to consider a nulled field and the absence of a field as the same thing.

Not all fields appear in all contexts. For example response with error messages
may not contain fields for data, dimensions and attributes.

----

## <a name="Introduction"></a>Introduction
Let's first start with a brief introduction about the SDMX information model.

In order to make sense of some statistical data, we need to know the concepts 
associated with them. For example, on its own the figure 1.2953 is pretty meaningless, 
but if we know that this is an exchange rate for the US dollar against the euro on 
23 November 2006, it starts making more sense. 

There are two types of concepts: dimensions and attributes. Dimensions, when combined, 
allow to uniquely identify statistical data. Attributes on the other hand do not help 
identifying statistical data, but they add useful information (like the unit of measure 
or the number of decimals). 

The measurement of some phenomenon (e.g. the figure 1.2953 mentioned above) is known as an
"observation" in SDMX. Observations are grouped together into a "dataset". However, there
can also be an intermediate grouping. For example, all exchange rates for the US dollar 
against the euro can be measured on a daily basis and these measures can then be
grouped together, in a so-called "time series". Similarily, you can group a collection of 
observations made at the same point in time, in a "cross-section" (for example, 
the values of the US dollar, the Japanese yen and the Swiss franc against the euro at a
particular date).

The SDMX information model is much richer than this limited introduction, 
however the above should be sufficient to understand the JSON format proposed here. For
additional information, please refer to the [SDMX documentation](http://sdmx.org/?page_id=10).

----

## <a name="Message"></a>Message

Message is the response you get back from the RESTful API. Message is the top
level object and it contains dimensions, attributes and other
fields. Example:

    {
      "sdmx-proto-json": "2012-11-15",
      "header": {
        "name": "BIS Effective Exchange Rates",
        "id": "b1804c51-1ee3-45a9-bb75-795cd4e06489",
        "prepared": "2012-05-04T03:30:00"
      },
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

*String*. A string that specifies the version of the SDMX-PROTO-JSON response. Example:

    "sdmx-proto-json": "2012-11-15"

### header

*[Header](#Header)*. Header contains basic information used in message exchanges.
Example:

    "header": {
      "name": "BIS Effective Exchange Rates",
      "id": "b1804c51-1ee3-45a9-bb75-795cd4e06489",
      "prepared": "2012-05-04T03:30:00"
    },


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
      "ADJUSTMENT": {
        "id": "ADJUSTMENT",
        "name": "Adjustment indicator",
        "type": null,
        "codes": [
          {
            "id": "N",
            "name": "Neither seasonally or working day adjusted",
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
      "OBS_COM": {
        "id": "OBS_COM",
        "name": "Observation comment",
        "code": null,
        "default": null
      },
      "UNIT_MULT": {
        "id": "UNIT_MULT",
        "name": "Unit multiplier",
        "codes": {
          "id": [
            "0"
          ],
          "0": {
            "id": "0",
            "name": "Units",
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


## <a name="Header"></a>Header

Header contains basic header information for the message exhange. Example

    "header": {
      "id": "b1804c51-1ee3-45a9-bb75-795cd4e06489",
      "prepared": "2013-01-03T12:54:12",
      "name": "BIS Effective Exchange Rates",
      "sender: {
        "id": "SDMX"
      }
    }

### id

*String*. Unique string that identifies the message for further reference.
Example:

    "id": "TEC00034"

### name

*String* *nullable*. Brief summary of the message contents. Example:

    "name": "Short-term interest rates: Day-to-day money rates"

### test

*Boolean* *nullable*. Test indicates whether the message is for test purposes or not. False for normal messages. Example:

    "test": false

### prepared

*String*. Prepared is the date the message was prepared. String representation
of Date formatted according to the ISO-8601 standard. Example:

    "prepared": "2012-05-04T03:30:00"
    
### sender

```Currently subset of the SMDX-Ml functionality```

*Object*. Sender is information about the party that is transmitting the message.
Sender contains the following fields:

* id - *string*. The id attribute holds the identification of the party.
* name - *string* *nullable*. Name is a human-readable name of the party.

Example:

    "sender": {
      "id": "SDMX"
    }
    
### structure

```Currently subset of the SMDX-ML functionality```

*Object* *nullable*. Structure provides a reference to the structure (either explicitly or through a structure usage reference) that describes the format of data or reference metadata. In addition to the structure, it is required to also supply the namespace of the structure specific schema that defines the format of the data/metadata. For cross sectional data, additional information is also required to state which dimension is being used at the observation level. This information will allow the structure specific schema to be generated. For generic format messages, this is used to simply reference the underlying structure. It is not mandatory in these cases and the generic data/metadata sets will require this reference explicitly.

Structure contains following fields:

* dimensionAtObservation - *String* *nullable*. The dimensionAtObservation is used to reference the dimension at the observation level for data messages. This can also be given the explicit value of "AllDimensions" which denotes that the cross sectional data is in the flat format.

* explicitMeasures - *Boolean* *nullable*. The explicitMeasures indicates whether explicit measures are used in the cross sectional format. This is only applicable for the measure dimension as the dimension at the observation level or the flat structure.

* ref - *Object* *nullable*. References the structure which defines the structure of the data or metadata set. Ref contains following fields:

    * agencyID - *String*. The agencyID attribute identifies the maintenance agency for the object being referenced (agency-id in the URN structure). This is optional to allow for local references (where the other reference fields are inferred from another context), but all complete references will require this.
    
    * id - *String*. The id attribute identifies the object being referenced, and is therefore always required.
    
    * version - *String* *nullable*. The version attribute identifies the version of the object being reference, if applicable. If this is available, a default value of 1.0 will always apply.
    
Example:

    "structure": {
      "dimensionAtObservation": "AllDimensions",
      "ref": {
        "agencyID": "ECB",
        "id": "ECB_EXR1",
        "version": "1.0"
      }
    } 

    
### dataSetID

*String* *nullable*. DataSetID provides an identifier for a contained data set.
Example:

    "dataSetID": "ECB_EXR1"

### dataSetAction

```Following is a direct copy from the SDMX-ML Schema Docs```

*String* *nullable*. DataSetAction provides a list of actions, describing the intention of the data transmission from the sender's side. Each action provided at the data or metadata set level applies to the entire data set for which it is given. Note that the actions indicated in the Message Header are optional, and used to summarize specific actions indicated with this data type for all registry interactions. The "Informational" value is used when the message contains information in response to a query, rather than being used to invoke a maintenance activity. ```Default value is Informational```

* Append - this is an incremental update for an existing data/metadata set or the provision of new data or documentation (attribute values) formerly absent. If any of the supplied data or metadata is already present, it will not replace that data or metadata. This corresponds to the "Update" value found in version 1.0 of the SDMX Technical Standards.

* Replace - data/metadata is to be replaced, and may also include additional data/metadata to be appended. The replacement occurs at the level of the observation - that is, it is not possible to replace an entire series.

* Delete - data/metadata is to be deleted. Deletion occurs at the lowest level object. For instance, if a delete data message contains a series with no observations, then the entire series will be deleted. If the series contains observations, then only those observations specified will be deleted. The same basic concept applies for attributes. If a series or observation in a delete message contains attributes, then only those attributes will be deleted.

* Informational - data/metadata is being exchanged for informational purposes only, and not meant to update a system.

Example:

    "dataSetAction": "Informational"

### extracted

*String* *nullable*. Extracted is a time-stamp from the system rendering the data.
Example:

    "extracted": "2012-05-04T03:30:00"

### embargoDate

*String* *nullable*. EmbargoDate holds a ISO-8601 time period before which the data included in this message is not available. Example:

    "embargoDate": "2012-05-04"
    
### source

*Array* *nullable*. Source provides human-readable information about the source of the data. Example:

    "source": [
      "European Central Bank and European Commission"
    ]
    
### reportingBegin

*String* *nullable*. ReportingBegin provides the start of the time period covered by the message. Example:

    "reportingBegin": "2012-05-04"

### reportingEnd

*String* *nullable*. ReportingEnd provides the end of the time period covered by the message. Example:

    "reportingEnd": "2012-06-01"

----


## <a name="Data"></a>Data

Data object is a container for the data and reference metadata. 

Data can be represented as a flat list of observations or can be grouped into collections (slices) that can be either time series or cross-sections.

When data are grouped into collections, data object contains three fields: dimensions, attributes and observations. Example:

    {
      "dimensions": [ 0, 0, 0, 0, 0, 0 ],
      "attributes": [
        "P1M",
        "A",
      ],
      "observations": [
        [ 0, 105.6, null, null ],
        [ 1, 105.9 ],
        [ 2, 106.9 ],
        [ 3, 107.3, "P" ]
      ]
    }

In this case, data objects map directly to series in SDMX-ML messages (series, in SDMX 2.1, is a generic term that covers both time series and cross-sections). Series have both dimensions and observations fields. Attributes
field is optional in case there are no attributes at the series level. The array values in the dimensions field are always integers (null is not possible).

### dimensions

*Array* *nullable*. An array of dimension values. Each value is an index to the
*codes* array in the respective *Dimension* object. 

    // Dimensions for series
    "dimensions": [
      0,
      93,
      12,
      1
    ]

Dimension values map to the codes in the *Dimension* objects. The array index maps to the array index in the *Dimensions* *id* field and this allows lookup for the corresponding code array. Example:

1. Dimensions array for a data object is [0,93,12,1]. The *id* field in the message *dimensions* object is [ "FREQ" , "REF_AREA" , "ADJUSTMENT" , "ICP_ITEM" ].
2. First value 0 maps to the first value in the *codes* field for the dimension "FREQ".
3. Second value 93 maps to the 93rd value in the *codes* field for the dimension "REF_AREA" etc.


### attributes

*Array* *nullable*. Collection of attributes values. Example:

    "attributes": [
      "P1M",
      "A"
    ]


### observations

*Array* *nullable*. An array of observation values. Each observation value is an
array of two of more values.

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
        [ 1, null, "M" ]
      ]
    }

First element in an observation value array is index value of the observation level dimension. Observation level dimension is the last dimension in the *dimensions* *id* field. Second element is the observation value. The data type
for observation value is *Number*. Data type for a reported missing observation value is a *null*.

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

*[Code](#Code)*. Array of codes for the dimension. Example:

    "codes": [
      {
        "id": "M",
        "name": "Monthly",
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

### codes

*[Code](#Code)* *nullable*. Collection of codes for the attribute. Null if the
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
        "order": 0
      },
      "E": {
        "id": "E",
        "name": "Estimated value",
        "order": 1
      },
      "M": {
        "id": "M",
        "name": "Missing value; data cannot exist",
        "order": 2
      },
      "A": {
        "id": "P",
        "name": "Provisional value",
        "order": 3
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

### default

*String* or *Number* *nullable*. Defines a default value for the attribute. If
no value is provided then this value applies. Example:

    "default": "A"

----

## <a name="Code"></a>Code

Codes are used in all dimensions and coded attributes (uncoded attributes do not
use codes). Examples:

    {
      "id": "A",
      "name": "Normal value",
      "order": 0
    }


    {
      "id": "2008-01",
      "name": "2008-01",
      "order": "144",
      "start": "2008-01-01T00:00:00.000Z",
      "end": "2008-01-31T23:59:59.000Z"
    }

### id

*String*. Unique identifier for a code. Example:

    "id": "A"

### name

*String*. Human-readable name for a code. Example:

    "name": "Missing value; data cannot exist"

### description

*String* *nullable*. Description provides a plain text, human-readable
description of the code. Example:

    "description": "Provisional value"

### order

*Number* *nullable*. Default display order for the code. Example:

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
(dimension type is 'time'). Value is a date in ISO format for the beginning of the
period. Example:

    "start": "2007-02-01T00:00:00.000Z"

### end

*String* *nullable*. End date for a code in a time dimension.
This field is useful only when the codes are time periods for a time dimension
(dimension type is 'time'). Value is a date in ISO format for the end of the
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
