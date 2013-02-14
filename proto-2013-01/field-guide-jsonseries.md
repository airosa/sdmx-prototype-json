# Draft Field Guide to SDMX-PROTO-JSON Objects

**json-slice format**

Use this guide to better understand SDMX-PROTO-JSON objects.

- [Introduction](#Introduction)
- [Message](#Message)
- [Header](#Header)
- [Structure](#Structure)
- [DataSets](#DataSets)
- [Tutorial: Handling component values](#handling_values)

New fields may be introduced in later versions of the field guide. Therefore
consuming applications should tolerate the addition of new fields with ease.

The ordering of fields in objects is undefined. The fields may appear in any order
and consuming applications should not rely on any specific ordering. It is safe to consider a nulled field and the absence of a field as the same thing.

Not all fields appear in all contexts. For example response with error messages
may not contain fields for data, dimensions and attributes.

----

## <a name="Introduction"></a>Introduction
Let's first start with a brief introduction of the SDMX information model.

In order to make sense of some statistical data, we need to know the concepts
associated with them. For example, on its own the figure 1.2953 is pretty meaningless,
but if we know that this is an exchange rate for the US dollar against the euro on
23 November 2006, it starts making more sense.

There are two types of concepts: dimensions and attributes. Dimensions, when combined,
allow to uniquely identify statistical data. Attributes on the other hand do not help
identifying statistical data, but they add useful information (like the unit of measure
or the number of decimals). Dimensions and attributes are known as "components".

The measurement of some phenomenon (e.g. the figure 1.2953 mentioned above) is known as an
"observation" in SDMX. Observations are grouped together into a "data set". However, there
can also be an intermediate grouping. For example, all exchange rates for the US dollar
against the euro can be measured on a daily basis and these measures can then be
grouped together, in a so-called "time series". Similarly, you can group a collection of
observations made at the same point in time, in a "cross-section" (for example,
the values of the US dollar, the Japanese yen and the Swiss franc against the euro at a
particular date). Of course, these intermediate groupings are entirely optional and you
may simply decide to have a flat list of observations in your data set.

The SDMX information model is much richer than this limited introduction,
however the above should be sufficient to understand the JSON format proposed here. For
additional information, please refer to the [SDMX documentation](http://sdmx.org/?page_id=10).

----

## <a name="Message"></a>Message

Message is the response you get back from the SDMX RESTful API. Message is the top
level object and it contains the data as well as the metadata needed to interpret those data.
Example:

    {
      "sdmx-proto-json": "2012-11-15",
      "header": {
        "name": "BIS Effective Exchange Rates",
        "id": "b1804c51-1ee3-45a9-bb75-795cd4e06489",
        "prepared": "2012-05-04T03:30:00"
      },
      "structure": {
        # structure objects #
      },
      "dataSets": [
        # data set objects #
      ],
      "errors": null
    }

### sdmx-proto-json

*String*. A string that specifies the version of the SDMX-PROTO-JSON response. A list of valid versions will
be released later on. Example:

    "sdmx-proto-json": "2012-11-15"

### Header

*Object* *nullable*. *Header* contains basic information about the message. Example:

    "header": {
      "name": "BIS Effective Exchange Rates",
      "id": "b1804c51-1ee3-45a9-bb75-795cd4e06489",
      "prepared": "2012-05-04T03:30:00"
    }

### structure

*Object* *nullable*. *Structure* contains the information needed to interpret the data available in the message. Example:

    "structure": {
        "id": "ECB_EXR_WEB",
        "ref": "http://sdw-ws.ecb.europa.eu/dataflow/ECB/EXR/1.0",
        "components": {
            # components object #
        },
        "packaging": {
            # packaging object #
        }
    }

### dataSets

*Array* *nullable*. *DataSets* field is an array of *[DataSet](#DataSet)* objects. That's where the data (i.e.: the observations)
will be. In typical cases, the file will
contain only one data set. However, in some cases, such as when retrieving, from an SDMX 2.1 web service, what has
changed in the data source since in particular point in time, the web service might return more than one data set.
Example:

    "dataSets": [
      {
        "dataSetAction": "Informational",
        "extracted": "2012-05-04T03:30:00",
        "series": [
          # data object #
        ]
      }
    ]

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

Header contains basic information about the message. Example:

    "header": {
      "id": "b1804c51-1ee3-45a9-bb75-795cd4e06489",
      "prepared": "2013-01-03T12:54:12",
      "name": "BIS Effective Exchange Rates",
      "sender: {
        "id": "SDMX"
      }
    }

### id

*String*. Unique string that identifies the message for further references.
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

    "prepared": "2012-05-04T03:30:00Z"

### sender

```Currently subset of the SMDX-ML functionality```

*Object*. Sender is information about the party that is transmitting the message.
Sender contains the following fields:

* id - *string*. The id attribute holds the identification of the party.
* name - *string* *nullable*. Name is a human-readable name of the party.

Example:

    "sender": {
      "id": "SDMX"
    }

### receiver

```Currently subset of the SMDX-ML functionality```

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

## <a name="Structure"></a>structure

```Currently subset of the SMDX-ML functionality```

*Object* *nullable*. Structure provides the structural metadata necessary to interpret the data contained in the message.
It tells you which are the components (dimensions and attributes) used in the message and also describes to which
level in the hierarchy (data set, series, observations), these components are attached.

Example:

    "structure": {
        "id": "ECB_EXR_WEB",
        "href": "http://sdw-ws.ecb.europa.eu/dataflow/ECB/EXR/1.0",
        "components": {
            # components object #
        },
        "packaging": {
            # packaging object #
        }
    }

### id

*String* *nullable*. An identifier for the structure. Example:

    "id": "ECB_EXR_WEB"

### href

*String* *nullable*. A link to a SDMX 2.1 web service resource where additional information regarding the structure is
available. Example:

    "href": "http://sdw-ws.ecb.europa.eu/dataflow/ECB/EXR/1.0"
    
### ref

*Object* *nullable*. Provides the 4 elements necessary to uniquely identify structural metadata that offers additional 
information about the data contained in the message. Example:

    "ref": {
        "type": "dataStructure",
        "agencyID": "ECB",
        "id": "EXR",
        "version": 1.0
    }
    
The ref element may contain the following elements:    

#### type

*String*. The type of structural metadata. The following values are allowed: dataStructure, dataflow, provisionAgreement.
For additional information about these, please refer to the [SDMX documentation](http://sdmx.org/?page_id=10). Example:

    "type": "dataStructure"

#### agencyID

*String*. The ID of the agency maintaining the structural metadata. Example:

    "agencyID": "ECB"

#### id

*String*. The ID of the structural metadata. Example:

    "id": "EXR"

#### version

*String* *nullable*. The version of the structural metadata. If not supplied, defaults to 1.0. Example:

    "version": 1.0    

### components

*Object*. A collection of [components](#Component) (dimensions and attributes) used in the message. Example:

    "components": {
      "FREQ": {
        # component object #
      },
      "CURRENCY": {
        # component object #
      },
      "OBS_STATUS": {
        # component object #
      },
      "TIME_PERIOD": {
        # component object #
      }
    }

### <a name="packaging"></a>packaging

*Object*. Describes to which level in the hierarchy (data set, series, observations), the components are attached. Example:

    "packaging": {
        "dataSetDimensions": ["FREQ", "CURRENCY_DENOM", "EXR_TYPE", "EXR_SUFFIX"],
        "seriesDimensions": ["CURRENCY"],
        "observationDimensions": ["TIME_PERIOD"],
        "dataSetAttributes": [],
        "seriesAttributes": ["TITLE"],
        "observationAttributes": ["OBS_STATUS"]
    }

### <a name="Component"></a>Component

A component represents a dimension or an attribute used in the message. It contains basic information about the component
(such as its name and id) as well as the list of values used in the message for this particular component. Example:

    "FREQ": {
        "id": "FREQ",
        "name": "Frequency",
        "values": [
          {
            # value object #
          }
        ]
      }

Each of the components may contain the following fields

#### id

*String*. Identifier for the component.
Example:

    "id": "FREQ"

#### name

*String*. Name provides for a human-readable name for the object.
Example:

    "name": "Frequency"

#### description

*String* *nullable*. Provides a description for the object. Example:

    "description": "The time interval at which observations occur over a given time period."

#### role

*String* *nullable*. Defines the component role(s). For normal components the value
is null. Components can play various roles, such as, for example:

- **time**. Time dimension is a special dimension which designates the period in
time in which the data identified by the full series key applies.
- **measure**. Measure dimension is a special type of dimension which defines
multiple measures.

Example:

    "role": "time"

#### default

*String* or *Number* *nullable*. Defines a default value for the component (valid for attributes only!). If
no value is provided then this value applies. Example:

    "default": "A"

#### values

Array of [values](#component_values) for the components. Example:

    "values": [
      {
        "id": "M",
        "name": "Monthly",
        "orderBy": 0
      }
    ]

#### <a name="component_values"></a>Component value

*Object* *nullable*. A particular value for a component in a message. Example:

    {
        "id": "M",
        "name": "Monthly",
        "orderBy": 0
    }

##### id

*String*. Unique identifier for a value. Example:

    "id": "A"

##### name

*String*. Human-readable name for a value. Example:

    "name": "Missing value; data cannot exist"

##### description

*String* *nullable*. Description provides a plain text, human-readable
description of the value. Example:

    "description": "Provisional value"

##### orderBy

*Number* *nullable*. Default display order for the value. Example:

    "orderBy": 64

##### parent

*String* *nullable*. Parent value (for code hierarchies). If parent is null then
the value does not belong to any hierarchy. Hierarchy root values have special
value "ROOT" for the parent. There may be multiple roots. Each value has only one
parent. Example:

    "parent": "U2"

##### start

*String* *nullable*. Start date for the period in a time dimension.
This field is useful only when the value represents a period for a time dimension
(dimension type is 'time'). Value is a date in ISO format for the beginning of the
period. Example:

    "start": "2007-02-01T00:00:00.000Z"

##### end

*String* *nullable*. End date for period in a time dimension.
This field is useful only when the value represents a period for a time dimension
(dimension type is 'time'). Value is a date in ISO format for the end of the
period. Example:

    "end": "2007-10-31T23:59:59.000Z"

##### geometry

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

----

## <a name="DataSets"></a>DataSets

DataSets object is an array of data set objects. Example:

    "dataSets": [
      {
        "dataSetAction": "Informational",
        "extracted": "2012-05-04T03:30:00",
        "series": [
          # data object #
        ]
      }
    ]

There are between 2 and 3 levels in a data set object, depending on the way the data in the message is organized.

A data set may contain a flat list of observations. In this scenario, we have 2 levels in the data part of the message:
the data set level and the observation level.

A data set may also organize observations in logical groups called series. These groups can represent time series or
cross-sections. In this scenario, we have 3 levels in the data part of the message: the data set level, the
series level and the observation level.

Dimensions and attributes may be attached to any of these 3 levels. The way this is done in a particular message is
documented in the [packaging element](#packaging).

Observations will be found directly under a data set object, in case the data set is a flat list of observations. In
case the data set represents time series or cross sections, the observations will be found under the series elements.

### dataSetID

*String* *nullable*. DataSetID provides an identifier for the data set.
Example:

    "dataSetID": "ECB_EXR_2011-06-17"

### dataSetAction

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

### dimensions

*Array* *nullable*. Collection of [dimensions values](#dimension) attached to the data set level. This is typically the case when a
particular dimension always has the same value for the data available in the data message. In order to avoid repetition,
that value can simply be attached at the data set level.

### attributes

*Array* *nullable*. Collection of [attributes values](#attributes) attached to the data set level. This is typically the case when a
particular attribute always has the same value for the data available in the data message. In order to avoid repetition,
that value can simply be attached at the data set level.

### observations

*Array* *nullable*. Collection of [observations](#observations) directly attached to a data set. This is the case when
a data set represents a flat collection of observations. In case the observations are organised into logical groups
(time series or cross-sections), use the [series element](#series) instead.

### <a name="series"></a> series

*Array* *nullable*. A collection of series. Each series object contains the observation values and associated metadata (dimensions and attributes), when
the observations contained in the data set are used into logical groups (time series or cross-sections). This element must
not be used in case the data set represents a flat list of observations! Example:

    {
      "dimensions": [ 0, 0, 0, 0, 0, 0 ],
      "attributes": [ 0, 1 ],
      "observations": [
        [ 0, 105.6, null, null ],
        [ 1, 105.9 ],
        [ 2, 106.9 ],
        [ 3, 107.3, 0 ]
      ]
    }

#### <a name="dimensions"></a>dimensions

*Array* *nullable*. An array of dimension values. Each value is an index to the
*values* array in the respective *Dimension* object.

    // Dimensions for series
    "dimensions": [
      0,
      93,
      12,
      1
    ]

For information on how to handle the dimension values, see the section dedicated to [handling component values](#handling_values).

#### <a name="attributes"></a>attributes

*Array* *nullable*. Collection of attributes values. Each value is an index to the
*values* array in the respective *Attribute* object. Example:

    "attributes": [ 0, 1 ]

For information on how to handle the attribute values, see the section dedicated to [handling component values](#handling_values).

#### <a name="observations"></a>observations

*Array* *nullable*. An array of observation values. Each observation value is an
array of two of more values.

    "observations": [
        [ 0, 105.6, null, null ],
        [ 1, 105.9 ],
        [ 2, 106.9 ],
        [ 3, 107.3, 0 ]
    ]

The first elements in an observation value array are the index values of the observation level dimensions. It's typically one
for time series and cross-sections, but there can be more than one when the data set represents a flat list of
observations.

Then comes the observation value. The data type for observation value is *Number*. Data type for a reported
missing observation value is a *null*.

Elements after the observation value are values for the observation level attributes.

----

## <a name="handling_values"></a>Handling component values

Let's say that the following message needs to be processed:

    {
        "sdmx-proto-json": "2012-11-29",
        "header": {
            "id": "62b5f19d-f1c9-495d-8446-a3661ed24753",
            "prepared": "2012-11-29T08:40:26",
            "sender": {
                "id": "ECB",
                "name": "European Central Bank"
            },
            "name": "Sample time series data message"
        },
        "structure": {
            "id": "ECB_EXR_WEB",
            "href": "http://sdw-ws.ecb.europa.eu/dataflow/ECB/EXR/1.0",
            "components": {
                "FREQ": {
                    "id": "FREQ",
                    "name": "Frequency",
                    "values": [
                        {
                            "id": "D",
                            "name": "Daily"
                        }
                    ]
                },
                "CURRENCY": {
                    "id": "CURRENCY",
                    "name": "Currency",
                    "values": [
                        {
                            "id": "NZD",
                            "name": "New Zealand dollar"
                        }, {
                            "id": "RUB",
                            "name": "Russian rouble"
                        }
                    ]
                },
                "CURRENCY_DENOM": {
                    "id": "CURRENCY_DENOM",
                    "name": "Currency denominator",
                    "values": [
                        {
                            "id": "EUR",
                            "name": "Euro"
                        }
                    ]
                },
                "EXR_TYPE": {
                    "id": "EXR_TYPE",
                    "name": "Exchange rate type",
                    "values": [
                        {
                            "id": "SP00",
                            "name": "Spot rate"
                        }
                    ]
                },
                "EXR_SUFFIX": {
                    "id": "EXR_SUFFIX",
                    "name": "Series variation - EXR context",
                    "values": [
                        {
                            "id": "A",
                            "name": "Average or standardised measure for given frequency"
                        }
                    ]
                },
                "TIME_PERIOD": {
                    "id": "TIME_PERIOD",
                    "name": "Time period or range",
                    "values": [
                        {
                            "id": "2013-01-18",
                            "name": "2013-01-18",
                            "start": "2013-01-18T00:00:00.000Z",
                            "end": "2013-01-18T23:59:59.000Z"
                        }, {
                            "id": "2013-01-21",
                            "name": "2013-01-21",
                            "start": "2013-01-21T00:00:00.000Z",
                            "end": "2013-01-21T23:59:59.000Z"
                        }
                    ]
                },
                "TITLE": {
                    "id": "TITLE",
                    "name": "Series title",
                    "values": [
                        {
                            "name": "New zealand dollar (NZD)"
                        }, {
                            "name": "Russian rouble (RUB)"
                        }
                    ]
                },
                "OBS_STATUS": {
                    "id": "OBS_STATUS",
                    "name": "Observation status",
                    "values": [
                        {
                            "id": "A",
                            "name": "Normal value"
                        }
                    ]
                }
            },
            "packaging": {
                "dataSetDimensions": ["FREQ", "CURRENCY_DENOM", "EXR_TYPE", "EXR_SUFFIX"],
                "seriesDimensions": ["CURRENCY"],
                "observationDimensions": ["TIME_PERIOD"],
                "dataSetAttributes": [],
                "seriesAttributes": ["TITLE"],
                "observationAttributes": ["OBS_STATUS"]
            }
        },
        "dataSets": [
            {
                "extracted": "2013-01-21T15:20:00.000Z",
                "dataSetAction": "Informational",
                "dimensions": [0, 0, 0, 0],
                "series": [
                    {
                        "dimensions": [0],
                        "attributes": [0],
                        "observations": [
                            [0, 1.5931, 0],
                            [1, 1.5925, 0]
                        ]
                    }, {
                        "dimensions": [1],
                        "attributes": [1],
                        "observations": [
                            [0, 40.3426, 0],
                            [1, 40.3000, 0]
                        ]
                    }
                ]
            }
        ]
    }

There is only one data set in the message, and it contains two series.

    {
        "dimensions": [0],
        "attributes": [0],
        "observations": [
            [0, 1.5931, 0],
            [1, 1.5925, 0]
        ]
    },
    {
        "dimensions": [1],
        "attributes": [1],
        "observations": [
            [0, 40.3426, 0],
            [1, 40.3000, 0]
        ]
    }

The packaging field tells us that, out of the 6 dimensions, 4 have the same value for the 2 series and are therefore
attached to the data set level:

    "packaging": {
        "dataSetDimensions": ["FREQ", "CURRENCY_DENOM", "EXR_TYPE", "EXR_SUFFIX"],
        "seriesDimensions": ["CURRENCY"],
        "observationDimensions": ["TIME_PERIOD"],
        "dataSetAttributes": [],
        "seriesAttributes": ["TITLE"],
        "observationAttributes": ["OBS_STATUS"]
    }

We see that, for the first series, we get the value 0:

    "dimensions": [0]

From the packaging information, we know that the identifier of the dimension for this series is CURRENCY.

    "seriesDimensions": ["CURRENCY"]

We can now find the CURRENCY component in the collection of components available below the structure field:

    "CURRENCY": {
        "id": "CURRENCY",
        "name": "Currency",
        "values": [
            {
                "id": "NZD",
                "name": "New Zealand dollar"
            },
            {
                "id": "RUB",
                "name": "Russian rouble"
            }
        ]
    }

The value 0 identified previously is the index of the item in the collection of values for this component. In this case,
the dimension value is therefore "New Zealand dollar".

The same logic applies when mapping attributes.
