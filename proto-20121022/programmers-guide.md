# Draft Programmer's Guide to SDMX-PROTO-JSON Objects

**Version 2012-09-13**

This guide covers programming topics related to SDMX-PROTO-JSON objects.

1. Introduction
2. Requesting data
    1. [Specify JSON as the preferred media type](#21)
    2. [Specify the preferred languages](#22)
    3. [Restrict the amount of information](#23)
    4. [Provide faster transmission speeds](#24)
3. Consuming responses

----

### <a name="21">2.1</a> Specify JSON as the preferred media type

SDMX Web Service Guidelines specify XML as the default media type for the
RESTful Web API. Therefore clients must use the standard *Accept* HTTP request 
header to specify JSON as the preferred media type. Only supported media type
for JSON is *application/JSON*. 

Set HTTP *Accept* request header to *application/json* for all requests to the 
server. Server will set the standard HTTP entity header *Content-Type* to 
*application/json* in the response. If the client does not use the *Accept*
header then the server may return the response in XML.

If an Accept header field is present, and if the server cannot send a response 
in JSON, then the server sends a 406 (not acceptable) response.

See [HTTP documentation]
(http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html) for more details. 


### <a name="22">2.2</a> Specify the preferred languages

The SDMX data model supports multilingual names and descriptions. However the 
response will always contain data in only one language. The client can specify the
preferred languages. If the server contains data in multiple languages it will 
send the response back in the clint's preferred language (if available).

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
in the reponse from the server. Following list shows the options that are 
available.

- **full**. Makes no restrictions on the information returned. This is the 
default option.

- **dataonly**. Does not return attributes. In the response the 
*attributes* field is always null. *dimensions* and *measure* fields are not
affected. This is usefull if the client does not need to handle attribute values.

- **serieskeysonly**. Does not return measure and attribute values. In the
response the *attributes* and *measure* fields are both always null. *dimensions*
field is not affected. This is useful for performance reasons, to return the 
series that match a certain query, without returning the actual data.

- **nodata**. Does not return measure values. In the response *measure* field is
always null. *dimensions* and *attributes* fields are not affected. This option
is probably not very useful for data visualisation applications.


### <a name="24">2.4</a> Provide faster transmission speeds

[HTTP compression](http://en.wikipedia.org/wiki/HTTP_compression) is a 
capability that can be built into web servers and web clients to make better use
of available bandwidth, and provide faster transmission speeds between both.

Use the standard HTTP request header *Accept-Encoding* with supported compression
schema names (gzip, deflate etc.) separated by commas. If the server supports one
or more compression schemas, it will compress the response and add a *Content-Encoding*
field in the HTTP response with the used schemas, separated by commas.

See [HTTP documentation]
(http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html) for more details. 
