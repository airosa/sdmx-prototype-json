# Draft Programmer's Guide to SDMX-PROTO-JSON Objects

**Version 2012-11-15**

This guide covers programming topics related to SDMX-PROTO-JSON objects.

1. Introduction
2. Making requests
    1.  [Specify JSON as the preferred media type](#21)
    2.  [Specify the preferred languages](#22)
    3.  [Restrict the amount of information](#23)
    4.  [Provide faster transmission speeds](#24)
    5.  [Group data values](#25)
    6.  [Access resources from a different domain in a browser](#26)
3. Consuming responses
    1.  [Check compatibility](#31)
    2.  [Display dimensions](#32)
    3.  [Display data](#33)
4. Programming RESTful Web Services
    1.  [Streaming responses from a time-series database](#41)

----

## 2. Making requests

### <a name="21">2.1</a> Specify JSON as the preferred media type

SDMX Web Service Guidelines specify XML as the default media type for the
RESTful Web API. Therefore clients must use the standard *Accept* HTTP request
header to specify JSON as the preferred media type. Following media types are
supported:

- *application/JSON* is the official media type for JSON. Use this media type
if you want to receive the response in the latest version of the format that
the service supports.
- *application/vnd.sdmx.data+json;version=2.1* is the version specific media
type for the data queries. Use this media type if want to make sure that
the response is in this specific version of the format for data queries.

Set HTTP *Accept* request header to one of the media types for all requests to the
server. Service will set the standard HTTP entity header *Content-Type* to the
appropriate media type in the response. If the client does not use the *Accept*
header then the service may return the response in XML.

If an Accept header field is present, and if the service cannot send a response
the requested media type, then the service sends a 406 (not acceptable) response.

See [HTTP documentation]
(http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html) for more details.


### <a name="22">2.2</a> Specify the preferred languages

The SDMX data model supports multilingual names and descriptions. However the
response will always contain data in only one language. The client can specify the
preferred languages. If the server contains data in multiple languages it will
send the response back in the client's preferred language (if available).

Use the standard HTTP header *Accept-Language* to set the preferred languages
in the request. The server will then set the *Content-Language* entity
header field to indicate the language in the response.

If no Accept-Language header is present in the request, the server assumes that
all languages are equally acceptable and uses its default language in the response.

There is currently no way to request a list of supported languages from the
server.

See [HTTP documentation]
(http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html) for more details.


### <a name="23">2.3</a> Restricting the amount of information

Use the *detail* parameter in the data request to restrict the amount of information
in the response from the server. Following list shows the options that are
available.

- **full**. Makes no restrictions on the information returned. This is the
default option.

- **dataonly**. Does not return attributes. In the response the
*attributes* field is always null. *dimensions* and *measure* fields are not
affected. This is useful if the client does not need to handle attribute values.

- **serieskeysonly**. Does not return measure and attribute values. In the
response the *attributes* and *measure* fields are both always null. *dimensions*
field is not affected. This is useful for performance reasons, to return the
series that match a certain query, without returning the actual data.

- **nodata**. Does not return measure values. In the response *measure* field is
always null. *dimensions* and *attributes* fields are not affected. This option
is probably not very useful for data visualization applications.


### <a name="24">2.4</a> Provide faster transmission speeds

[HTTP compression](http://en.wikipedia.org/wiki/HTTP_compression) is a
capability that can be built into web servers and web clients to make better use
of available bandwidth, and provide faster transmission speeds between both.

Use the standard HTTP request header *Accept-Encoding* with supported compression
schema names (gzip, deflate etc.) separated by commas. If the server supports one
or more compression schemes, it will compress the response and add a *Content-Encoding*
field in the HTTP response with the used schemes, separated by commas.

See [HTTP documentation]
(http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html) for more details.


### <a name="25">2.5</a> Group data values

Data values in the response can be grouped by any dimension. Grouping is optional
but the default is determined by the service. For example
it is common to group data with a time dimension by time in order to process data
as time series. If the client does not need any grouping
it can request data in single flat array. This may be the most flexible option
as it is easy to use the flat array to display data in any grouping the user
wants to see.

Grouping is controlled with the *dimensionAtObservation* parameter. The default
value for the parameter is determined by the following rule:

1. If the data flow contains a time dimensions then the response is grouped by
the time dimension.
2. If the data flow contains a measure dimensions then the response is grouped
by the measure dimension.
3. If the data flow does not contain time or measure dimensions the the response
is not grouped by default.

Usually it is best the specify grouping in the request. Following options are
available:

- **AllDimensions**. Data in the response is in a flat array with no grouping.
Example:

      dimensionAtObservation=AllDimensions

- **Any dimension id**. Data in the response is grouped by the specified
dimension. Example:

    dimensionAtObservation=TIME_PERIOD

Grouping will typically reduce the size of the transmission because dimenision
values are not repeated for each observation. Good default choice is to include
dimensionAtObservation parameter only if the defaults above a not suitable.


### <a name="26">2.6</a> Access resources from a different domain in a browser

Cross-Origin Resource Sharing [CORS](http://www.w3.org/TR/cors/) is a web
standard that defines a mechanism that enables client-side cross-origin requests.
Browsers commonly prevent a client-side Web applications running from one origin
from obtaining data retrieved from another origin. This would restrict applications
making requests only to SDMX Web Services from the same origin.

CORS is supported by the browser so the client-side Web applications do not
have to be modified to support it. However CORS is supported only in [newer browser
versions](http://caniuse.com/cors) so Web applications should check that CORS
support is available.

SDMX Web Services guidelines recommend using HTTP basic authentication mechanism
for client authentication. However browsers do not generally support HTTP basic
authentication in cross-origin requests.

CORS requires also support from the Web Service. Web Services must provide
HTTP response headers defined in the CORS specification otherwise the browser
does not allow cross-origin requests.


----

## 3. Consuming responses

### <a name="31">3.1</a> Check compatibility

The response object always contains field *sdmx-proto-json* with the string value
of the version of the specification. The specification will evolve in the future
and therefore the contents of the response object will change.

Always check that the response object is compatible with the version of the
specification that your implementation supports. Implementations should consider
trying to handle newer versions, even if they may not support newer versions of
the specification.

### <a name="32">3.2</a> Display dimensions

Dimension is as a statistical concept used to identify a statistical series,
such as a time series, most probably together with other statistical concepts.
For example a statistical concept indicating certain economic activity or
a geographical reference area.

Dimensions of located in the *dimensions* field of the response object. Each
dimension has a unique identifier, all identifiers are located in the *id* array.
Each dimension is indexed with its identifier. Easiest way to loop over the
dimensions is to loop over the values of the *id* array and access the dimension
with the identifier. Following example prints the dimension names to the console.

    var i;
    var dims = response.dimensions;
    for (i = 0; i < dims.id.length; i += 1) {
      var d = dims[dims.id[i]];
      document.writeln(d.id);  // d.id == id
      document.writeln(d.name);
      if (d.description) {
        document.writeln(d.description);
      }
    }

Each dimension contains three textual fields that can be used for display:

- *id* is the unique short identifier for the dimension. This would be useful
only for expert users as it is aimed for automated processing.
- *name* is the human-readable name for the dimensions. This will always exist
and should always be displayed.
- *description* is the optional longer human-readable description of the
dimension. This should be displayed in addition to name if possible.

The length of the names depends on the statistical domain and the language used.
In general names are shorter than about 100 characters but in some cases they can
be longer. There is really no limitation on the length of descriptions. They can
also contain multiple paragraphs of text.

Dimension values are contained in the *codes* array field. Following example
prints names of all codes in all dimensions:

    var i, j;
    var dims = response.dimensions;
    for (i = 0; i < dims.id.length; i += 1) {
      var codes = response.dimensions[dims.id[i]].codes;
      for (j = 0; j < codes.length; j += 1) {
        var c = codes[j];
        document.writeln(c.id);
        document.writeln(c.name);
        if (c.description) {
          document.writeln(c.description);
        }
    }

Each code has the same textual fields as dimensions (in fact same three fields
exists for almost all objects in the message). Codes are typically displayed in
a list. *Name* field is the best choice to show in the list. In addition expert
users may want to see in the *id* field in addition to the name. Optionally
*description* (if available) contains more details.

It is better to be prepared to handle hundreds if not thousands of codes in a
dimension, e.g. postal codes, large statistical classification etc. It is easy
to check the number of codes by reading the length of the *codes* array field.
Some suggestions:

- Make sure that the control that displays the codes to the user is big enough
to handle the number and length of the code names. Dropdowns are usually a bad
idea, at least check the number of codes before you use one.
- If you are displaying tens or more codes provide a text field for filtering the
codes. Users can type in the information they want to see, e.g. name of a city.
- Display the total number of codes so users know how many codes they are dealing
with. If the control allows selections then display also the number of codes
selected.
- Sort the codes before displaying them to the user. Good default for the sort
ordering the is the *order* field. Alphabetical order may also work well.
Allow users to sort the codes themselves if possible.
- If a dimension has only one code then it is usually better not to show it the
same way as dimensions with more codes. As there is nothing to select this may
confuse users.

### <a name="33">3.2</a> Display data

Data and reference metadata is contained in the array field *data*. Each element
in the *data* array is an object with three optional fields:

- *dimensions* is an array of dimension values. These dimension values are common
to all observations in the same data object.
- *observations* is an array of observation level dimension values, observation
value and attribute values.
- *attributes* is an object that contains attribute values. These attribute values
are common to all observation values in the same data object.

Obviously the observation values should be displayed together with the dimension values.
Easiest is to start with an identifying set of dimension values or the
the series key. Following explanation is from the SDMX Users Guide:

>The concepts 1 to 6 above are required to identify our time series so we will us
>them as dimensions and will build our series key from them. Assuming that we use
>the order given above, a possible series key would look like this, taking the
>colon “:” to separate the dimension values:

>Q:GB:N:2:100:DE

>This would identify the quarterly (=Q), not seasonally adjusted (=N) exports
>(2=credit/exports) of goods (=100) from country United KIngdom (= GB) (the
>reporting country or area) to country Germany (= DE) (vis-à-vis area).

First you have to translate the key into an array of dimension index values.

    // Series key in an array - last dimension is the time period
    var key = ['Q', 'GB', 'N', '2', '100', 'DE', '2000'];
    var indices = [];

    //Find the index value for each code in the code
    var i;
    for (i = 0; i < key.length; i += 1) {
        //Find the dimension
        var dimId = response.dimensions.id[i]
        var dim = response.dimensions[dimId]

        // Find the index for the matching code
        indices.push dim.codes.filter(function(x){x.id === key[i]})[0].index

There are numerous ways to search the data array. Easiest is to simply iterate
over each element and compare the dimension values until there is a match.

    var match = function(x) {
        var j;
        for (j = 0; j < x.dimensions.length) {
            if (x.dimensions[j] != indices[j]) {
                return false;
            }
        }
        return true;
    }

    // find the matching data objects
    var matches = response.data.filter(match);

    // check if there was a match
    if (matches.length === 1) {
        // Assume that the observation level dimension (e.g. TIME_PERIOD) is last
        var period = indices[ indices.length - 1 ];

        // Find the matching observation
        var observations = matches[0].observations.filter(function(x){x[0] === period})

        // Check that the matching observation exists
        if (observations.length === 1) {
            // Display the observation
            document.writeln(key);
            document.writeln(observations[0][1]);
        }
    }

----

## 4. Creating a RESTful Service

### <a name="41">4.1</a> Streaming responses from a time-series database

Basic feature in for a SDMX web service is support for streaming responses back
to the client. With streaming the service does not need allocate resources for
complete responses and it can serve more clients and provide larger responses.

In principle JSON is fully compatible with streaming. Following is an example
from a streaming programming library [LitJson](http://litjson.sourceforge.net):

    using LitJson;
    using System;
    using System.Text;

    public class DataReader
    {
        public static void WriteJson ()
        {
            StringBuilder sb = new StringBuilder ();
            JsonWriter writer = new JsonWriter (sb);

            writer.WriteArrayStart ();
            writer.Write (1);
            writer.Write (2);
            writer.Write (3);

            writer.WriteObjectStart ();
            writer.WritePropertyName ("color");
            writer.Write ("blue");
            writer.WriteObjectEnd ();

            writer.WriteArrayEnd ();

            Console.WriteLine (sb.ToString ());
            // [1,2,3,{"color":"blue"}]
        }
    }

For objects first write the start of
an object then the field names followed by field value and finally the end
of an object. For arrays first write the start of an array, then each array
value and finally the end of an array.

The data objects in the *data* field are not dependent on other fields in the
message and they can be processed in any order. Dimension codes in the *dimensions* and
*observations* fields are indexed by the array position. It is necessary to keep
track of the array positions while writing out data objects. The message level
*dimensions* and *attributes* fields can be processed as the last step of the
message processing. The order of the dimension codes must match the indexing
used in the data objects.








