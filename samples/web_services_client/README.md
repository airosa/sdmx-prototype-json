SDMX JSON Prototype: Sample Queries for a Web Services Client
============================================================

The initial use case for the JSON prototype is serving a Web Service Client for
data visualisation. This sample adapts the example from the SDMX Technical
Standards Version 2.1 Section 7 "Guidelines for the Use of Web Services". In
this sample all requests use the RESTful API.


Step 1: Browsing an SDMX data source, using a list of subject-matter domains
----------------------------------------------------------------------------

The web client offers the possibility to retrieve data by browsing a list of
subject matter domains. The client requests the version currently in production
of the SDW_ECON category scheme, maintained by the ECB.

Using the references attribute with a value of “categorisation”, the
categorisations used by the category scheme will also be returned and these will
contain references to the dataflows attached to the categories.

    GET /categoryscheme/ECB/SDW_ECON?references=categorisation HTTP/1.1
    Host: http://ws-entry-point
    Accept: application/vnd.sdmx.structure+json;version=2.1
    
    HTTP/1.1 200 OK
    Content-Type: application/vnd.sdmx.structure+json;version=2.1
    
    JSON response (see 1_categoryscheme_response.json)

Response contains the category schemes, as well as the categorisations with
references to the dataflows will be returned.


Step 2: Selecting a dataflow
-----------------------------

Once a subject-matter domain and a dataflow have been selected, a filter box
needs to be populated, to allow users to select data. In order to only createh
queries for data that actually exist in the database, tphe dataflow constraints
will also be requested.

In this sample query, the dataflow id is 123456, the agency id is ECB and the
version is 1.2. Using the references attribute, the data structure definition
and the constraints will also be returned.

    GET /dataflow/ECB/123456/1.2?references=all HTTP/1.1
    Host: http://ws-entry-point
    Accept: application/vnd.sdmx.structure+json;version=2.1
    
    HTTP/1.1 200 OK
    Content-Type: application/vnd.sdmx.structure+json;version=2.1
    
    JSON response (see 2_dataflow_response.json)

Response contains the requested dataflow, as well as the data structure
definition and the dataflow constraints attached.

If, before selecting data, the user wants to review the data structure
definition used by the dataflow, this can be done without sending an additional
query, as this information has already been included in the response.


Step 3: Data selection
-----------------------

The user uses the dimension filters, to retrieve the data he is interested in.

Apart from the dataflow id (123456), the data provider is set to ECB, and the
series key uses the OR operator for the 5th dimension. Furthermore, only data
for 2009 should be returned. As the purpose of the returned data is to be
displayed on a graph, the detail level is set to data only. Therefore,
attributes and groups will be excluded from the returned message. 

Regarding the references to the dataflow, the short form is used, as, for this
particular web service, the dataflow id and the data provider id are sufficient
to uniquely identify the dataflow and the data provider respectively. Should
this not be the case, the full reference must be supplied (for example,
ECB+123456+1.2 instead of 123456).

    GET /data/123456/M.I4.N.9.339+340+341.N.A1.A/ECB?startPeriod=2009-01&endPeriod=2009-12&detail=dataonly HTTP/1.1
    Host: http://ws-entry-point
    Accept: application/vnd.sdmx.genericdata+json;version=2.1
    
    HTTP/1.1 200 OK
    Content-Type: application/vnd.sdmx.genericdata+json;version=2.1
    
    JSON response (see 3_data_response.json)

Response contains the requested time series.


