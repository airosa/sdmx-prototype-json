# Draft Field Guide to SDMX-PROTO-JSON Objects

**Version for jsonseries format**

Use this guide to better understand SDMX-PROTO-JSON objects.

- [Introduction](#Introduction)
- [Message](#Message)
- [Header](#Header)
- [DataSets](#DataSets)
- [Dimensions](#Dimensions)
- [Attributes](#Attributes)

New fields may be introduced in later versions of the field guide. Therefore
consuming applications should tolerate the addition of new fields with ease.

The ordering of fields in objects is undefined. The fields may appear in any order
and consuming applications should not rely on any specific ordering. However, in
case of large messages streamed back by a web service, it is considered good practice
to include the metadata information (header, dimensions and attributes) before the 
data. It is safe to consider a nulled field and the absence of a field as the same thing.

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
"observation" in SDMX. Observations are grouped together into a "data set". However, there
can also be an intermediate grouping. For example, all exchange rates for the US dollar 
against the euro can be measured on a daily basis and these measures can then be
grouped together, in a so-called "time series". Similarily, you can group a collection of 
observations made at the same point in time, in a "cross-section" (for example, 
the values of the US dollar, the Japanese yen and the Swiss franc against the euro at a
particular date). Of course, these intermediate groupings are entirely optional and you
may simply decide to have a flat list of observations in your data set.

The SDMX information model is much richer than this limited introduction, 
however the above should be sufficient to understand the JSON format proposed here. For
additional information, please refer to the [SDMX documentation](http://sdmx.org/?page_id=10).

----

## <a name="Message"></a>Message

Message is the response you get back from the RESTful API. Message is the top
level object and it contains the data as well as the metadata needed to interpret those data. 
Example:

    {
      "sdmx-proto-json": "2012-11-15",
      "header": {
        "name": "BIS Effective Exchange Rates",
        "id": "b1804c51-1ee3-45a9-bb75-795cd4e06489",
        "prepared": "2012-05-04T03:30:00"
      },
      "dataSets": [
        # data set objects #
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

*String*. A string that specifies the version of the SDMX-PROTO-JSON response. A list of valid versions will
be released later on. Example:

    "sdmx-proto-json": "2012-11-15"

### header

*[Header](#Header)*. Header contains basic information used in message exchanges.
Example:

    "header": {
      "name": "BIS Effective Exchange Rates",
      "id": "b1804c51-1ee3-45a9-bb75-795cd4e06489",
      "prepared": "2012-05-04T03:30:00"
    },


### dataSets

*Array* *nullable*. *DataSets* field is an array of *[DataSet](#DataSet)* objects. In typical cases, the file will
contain only one data set. However, in some cases, such as when retrieveing, from an SDMX 2.1 web service, what has
changed in the data source since in particular point in time, the web service might return more than one dataset. 
Example:

    "dataSets": [
      {
        "structure": {
          # structure object #
        },
        "dataSetAction": "Informational",
        "extracted": "2012-05-04T03:30:00",
        "data": [
          # data object #
        ]
      }    
    ]

### dimensions

*[Dimensions](#Dimensions)* *nullable*. Contains dimensions, that is, the statistical concepts that, when 
combined, allow to uniquely identify observations. Example:

    "dimensions": {
      "id": [
        "ADJUSTMENT"
      ],
      "ADJUSTMENT": {
        "id": "ADJUSTMENT",
        "name": "Adjustment indicator",
        "role": null,
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

*[Attributes](#Attributes)* *nullable*. Contains attributes, that is, the concepts that provide additional information
about the data contained in the dataset. Attributes can be attached to an observation (for example, to indicate 
whether a particular value is an estimate), a data set (for example, to indicate when the data contained in the data set
were last updated) and to a collection of observations (i.e.: a time series or a cross-section, for example, to give a 
human-friendly title to a particular grouping of observations). Example:

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
codes. In addition, whenever appropriate, the error can also be returned using
the error fields. Error is an array of error messages. If there are no errors
then error is null. Example:

    "errors": [
      "Invalid number of dimensions in parameter key"
    ]

----


## <a name="Header"></a>Header

Header contains basic header information for the message exchange. Example:

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
    
### receiver

```Currently subset of the SMDX-Ml functionality```

*Object* *nullable*. Receiver is information about the party that is receiving the message.
Receiver contains the following fields:

* id - *string*. The id attribute holds the identification of the party.
* name - *string* *nullable*. Name is a human-readable name of the party.

Example:

    "receiver": {
      "id": "SDMX"
    }    
    
### extracted

*String* *nullable*. Extracted is a timestamp indicating when the data have been extracted from the data source.
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
----


## <a name="DataSets"></a>DataSets

DataSets object is an array of *[DataSet](#DataSet)* objects. It also contains additional metadata. Example:

    "dataSets": [
      {
        "structure": {
          # structure object #
        },
        "dataSetAction": "Informational",
        "extracted": "2012-05-04T03:30:00",
        "data": [
          # data object #
        ]
      }    
    ]
    
### <a name="structure"></a>structure

```Currently subset of the SMDX-ML functionality```

*Object* *nullable*. Structure provides a reference to the data structure definition (DSD), that describes the 
format of data included in the message. In addition, it is also states which dimension is being used at the observation
level, if any (for example, TIME_PERIOD for time series).

Structure contains following fields:

* dimensionAtObservation - *String* *nullable*. The dimensionAtObservation is used to reference the dimension 
at the observation level for data messages. For time series, the value will be "TIME_PERIOD" while, for cross-sections,
it can be any of the other dimensions. This can also be given the explicit value of "AllDimensions", which denotes
that the data is in the flat format (i.e. no grouping of observations).

* explicitMeasures - *Boolean* *nullable*. The explicitMeasures indicates whether explicit measures are used in
the cross sectional format. This is only applicable for the measure dimension as the dimension at 
the observation level or the flat structure.

* ref - *Object* *nullable*. References the structure which defines the structure of the data or metadata set. 
Ref contains following fields:

    * agencyID - *String*. The id of the agency maintaining the data structure definition.
    
    * id - *String*. The id of the data structure definition that describes the data included in the message.
    
    * version - *String* *nullable*. The version attribute identifies the version of the data structure definition
    that describes the data included in the message.
    
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

*String* *nullable*. DataSetID provides an identifier for the data set.
Example:

    "dataSetID": "ECB_EXR_2011-06-17"

### dataSetAction

```Following is a direct copy from the SDMX-ML Schema Docs```

*String* *nullable*. DataSetAction provides a list of actions, describing the intention of the data transmission 
from the sender's side. ```Default value is Informational```

* Append - this is an incremental update for an existing data set or the provision of new data or documentation 
(attribute values) formerly absent. If any of the supplied data or metadata is already present, it will not replace
that data.

* Replace - data are to be replaced, and may also include additional data to be appended. 

* Delete - data are to be deleted. 

* Informational - data are being exchanged for informational purposes only, and not meant to update a system.

Example:

    "dataSetAction": "Informational"
    
### provider    

*Object* *nullable*. Provider is information about the party that provides the data contained in the dataset.
Provider contains the following fields:

* id - *string*. The id attribute holds the identification of the party.
* name - *string* *nullable*. Name is a human-readable name of the party.

Example:

    "provider": {
      "id": "EUROSTAT"
    }    

### reportingBegin

*String* *nullable*. ReportingBegin provides the start of the time period covered by the message. Example:

    "reportingBegin": "2012-05-04"

### reportingEnd

*String* *nullable*. ReportingEnd provides the end of the time period covered by the message. Example:

    "reportingEnd": "2012-06-01"    

### validFrom

*String* *nullable*. The validFromDate indicates the inclusive start time indicating the validity of the information in the data.

    "validFrom": "2012-01-01T10:00:00Z"

### validTo

*String* *nullable*. The validToDate indicates the inclusive end time indicating the validity of the information in the data.

    "validTo": "2013-01-01T10:00:00Z"

### publicationYear

*String* *nullable*. The publicationYear holds the ISO 8601 four-digit year.

    "publicationYear": "2005"

### publicationPeriod

*String* *nullable*. The publicationPeriod specifies the period of publication of the data in terms of whatever 
provisioning agreements might be in force (i.e., "2005-Q1" if that is the time of publication for a data set 
published on a quarterly basis).

    "publicationPeriod": "2005-Q1"
    
### attributes

*Array* *nullable*. Collection of attributes values attached to the data set level. Example:

    "attributes": [
      "A"
    ]

### Data

Data object contains the observation values and associated metadata (dimensions and attrbutes). 

Data can be represented as a flat list of observations or can be grouped into collections (slices) that can be either
time series or cross-sections.

When data are grouped into collections, data object contains three fields: dimensions, attributes and observations. 
Example:

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

In this case, data objects map directly to series in SDMX-ML messages (series, in SDMX 2.1, is a generic term that 
covers both time series and cross-sections). Series have both dimensions and observations fields. Attributes
field is optional in case there are no attributes at the series level. The array values in the dimensions field 
are always integers (null is not possible).

#### dimensions

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
3. Second value 93 maps to the 94th value in the *codes* field for the dimension "REF_AREA" etc.


#### attributes

*Array* *nullable*. Collection of attributes values. Example:

    "attributes": [
      "P1M",
      "A"
    ]


#### observations

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

First element in an observation value array is index value of the observation level dimension. 
Observation level dimension is the one defined in the dimensionAtObservation field of the [structure](#structure) element. 
Second element is the observation value. The data type for observation value is *Number*. Data type for a reported
missing observation value is a *null*.

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

*Array*. An array of identifiers for the dimensions contained in the message. The order of
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

*String* *nullable*. Provides a description for the object. Example:

    "description": "The time interval at which observations occur over a given time period."

### role

*String* *nullable*. Defines the dimension role(s). For normal dimensions the value
is null. Dimensions can play various roles, such as, for example:

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

*Array*. An array of identifiers for the attributes contained in the message. Example:

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
