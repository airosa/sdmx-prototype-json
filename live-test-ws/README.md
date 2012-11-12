# live-test-ws

Experimental SDMX RESTful web service for testing and development. Written in CoffeeScript, runs with Node.js. 

## Features

- RESTful web API compliant with SDMX 2.1 (only for data queries) 
- Responses in experimental JSON format
- Includes sample HICP data set published by the ECB
- Runs with node.js on linux, windows, mac etc.
- Nothing to install, just copy files to a directory
- No settings
- Start and stop the server from the command line
- Supports HTTP basic authorization scheme

## Benefits

- For web service client development
	- Quickly integrate RESTful web service in your development environment
	- Experiment with the SDMX RESTful web API
	- Automate unit tests
- For SDMX development
	- Fork the repo and experiment with new ideas for the SDMX API and data formats 
	- Demonstrate ideas with working code

## Installation

1. Check that [Node.js](http://nodejs.org) is installed.
2. Copy live-test-ws.js and hicp-coicop-inx.json from the Github repo

## Usage

Start the server from the command line:

	node live-test-ws.js

Server is now listening at port 8081. Press Ctrl-C to stop the server.

## Sample Data

Server includes sample data set published by the ECB. For more information about this data set see the [ECB web site](http://www.ecb.europa.eu/stats/prices/hicp/html/hicp_coicop_inx_latest.en.html). The data flow id is ECB_ICP1 and the provider id is ECB. Following query returns the dimensions and codes for the sample data set (replace localhost with your own server address):

[http://localhost:8081/data/ECB_ICP1?detail=nodata](http://localhost:8081/data/ECB_ICP1?detail=nodata)

Sample data set contains monthly consumer price indices for the euro area from January 1996 until February 2009. Data set contains six dimensions in addition to time period. Four dimensions have only one code. Dimensions with multiple codes are:

- Second dimension (reference area) contains 17 codes for the euro area and euro area countries.
- Fourth dimension (hicp item) contains 130 codes for consumer price indices classified by purpose. For example code 011300 is the consumer price index for fish.

Following are some sample queries:

- Return observations for Finland and Germany starting from January 2007
[http://localhost:8081/data/ECB_ICP1/M.FI+DE.N..4.INX?startPeriod=2007-01](http://localhost:8081/data/ECB_ICP1/M.FI+DE.N..4.INX?startPeriod=2007-01)

- Return observations for HICP item 000000 in December 2000 for all countries
[http://localhost:8081/data/ECB_ICP1/M..N.000000.4.INX?startPeriod=2000-12&endPeriod=2000-12](http://localhost:8081/data/ECB_ICP1/M..N.000000.4.INX?startPeriod=2000-12&endPeriod=2000-12)

For more information about the SDMX RESTful web API see the SDMX standard section 7 "Guidelines for the Use of Web Services". Please note that server supports only data queries. Queries for other resources in guidelines are currently not supported.

## Authentication

Server supports HTTP basic authorization scheme for testing client authentication.
Just add 'auth' to the URL between the hostname and pathname. Server will then 
request authentication with the basic authorization scheme. Username and password
are both 'test'. For example:

- Following query works without authentication http://localhost:8081/data/ECB_ICP1/M.FI+DE.N..4.INX?startPeriod=2007-01
- Server requests authentication for the following query
http://localhost:8081/auth/data/ECB_ICP1/M.FI+DE.N..4.INX?startPeriod=2007-01





