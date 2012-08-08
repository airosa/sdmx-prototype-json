http = require 'http'
url = require 'url'
fs = require 'fs'

#-------------------------------------------------------------------------------
# Globals and constants

SERVER_NAME = 'LIVE-TEST-WS'
SERVER_VERSION = '0.1'
PORT_NUMBER = 8081
DATA_FILE = 'hicp-coicop-inx.json'

dataset = null

#-------------------------------------------------------------------------------
# Logging

log = (msg) ->
    console.log "#{new Date().toTimeString()[0..7]} #{msg}"

#-------------------------------------------------------------------------------
# Functions for the initial loading of data

# Calculates index multipliers for all dimensions 
calculateIndexMultipliers = (dimensions) ->
    multipliers = new Array dimensions.length
    reversedDimensions = dimensions.slice().reverse()
    prev = 1
    for dim, i in reversedDimensions
        multipliers[i] = prev
        prev = dim.length * prev
    multipliers.reverse()


# Load in JSON format from a file
loadDataset = (filename) ->
    jsonString = fs.readFileSync filename
    data = JSON.parse jsonString
    data.indexMultipliers = calculateIndexMultipliers data.codes
    data

#-------------------------------------------------------------------------------
# Functions for date processing

# Parses dates in reporting period format e.g. 2010-Q1
# Returns a date object set to the beginning of the reporting period.
# if end is true return the beginning of the next period
parseReportingTimePeriod = (frequency, year, period, end) ->
    return null if year % 1 isnt 0
    return null if period % 1 isnt 0
    return null if period < 1

    date = new Date Date.UTC(year,0,1,0,0,0)
    period = period - 1 unless end

    switch frequency
        when 'A'
            return date
        when 'S'
            return null if 2 < period
            date.setUTCMonth date.getUTCMonth() + (6 * period)
        when 'T'
            return null if 3 < period
            date.setUTCMonth date.getUTCMonth() + (4 * period)
        when 'Q'
            return null if 4 < period
            date.setUTCMonth date.getUTCMonth() + (3 * period)
        when 'M'
            return null if 12 < period
            date.setUTCMonth date.getUTCMonth() + period
        when 'W'
            return null if 53 < period
            if date.getUTCDay() isnt 4
                date.setUTCMonth 0, 1 + (((4 - date.getUTCDay()) + 7) % 7)
            date.setUTCDate date.getUTCDate() - 3
            date.setUTCDate date.getUTCDate() + (7 * period)
        when 'D'
            return null if 366 < period
            date.setUTCDate date.getUTCDate() + period
        else
            return null

    date


# Parses time periods in all supported formats. 
# Returns date object set the beginning of the period. If end is true
# then returned date is set to the end of the period.
parseDate = (value, end) ->
    date = null

    if /^\d\d\d\d$/.test value
        date = new Date Date.UTC( +value, 0, 1, 0, 0, 0 )
        date.setUTCFullYear date.getUTCFullYear() + 1 if end
    else if /^\d\d\d\d-[A|S|T|Q]\d$/.test value
        date = parseReportingTimePeriod value[5], +value[0..3], +value[6], end
    else if /^\d\d\d\d-[M|W]\d\d$/.test value
        date = parseReportingTimePeriod value[5], +value[0..3], +value[6..7], end
    else if /^\d\d\d\d-D\d\d\d$/.test value
        date = parseReportingTimePeriod value[5], +value[0..3], +value[6..8], end
    else if /^\d\d\d\d-\d\d$/.test value
        date = new Date Date.UTC( +value[0..3], +value[5..6]-1 , 1 , 0 , 0 , 0 )
        date.setUTCMonth date.getUTCMonth() + 1 if end
    else if /^\d\d\d\d-\d\d-\d\d$/.test value
        date = new Date Date.UTC(+value[0..3],+value[5..6]-1,+value[8..9],0,0,0)
        date.setUTCDate date.getUTCDate() + 1 if end 
    else if /^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d$/.test value
        return Date.parse value, 'yyyy-MM-ddTHH:mm:ss'
    else
        return null   
    
    date.setUTCSeconds date.getUTCSeconds() - 1 if date? and end 

    date

#-------------------------------------------------------------------------------
# Functions for parsing the request url

parseFlowRef = (flowRefStr, dataQuery, response) ->
    if not flowRefStr? 
        response.setHeader 'Warning', '199 Mandatory parameter flowRef is missing'
        response.statusCode = 400
        return

    flowRef = flowRefStr.split ','
    switch flowRef.length
        when 1
            flowRef[1] = flowRef[0]
            flowRef[0] = 'ALL'
            flowRef[2] = 'LATEST'
        when 2
            flowRef[2] = 'LATEST'

    flowRefOk = flowRef[0] is 'ALL' or flowRef[0] is 'ECB'
    flowRefOk = flowRefOk and flowRef[1] is 'ECB_ICP1'
    flowRefOk = flowRefOk and flowRef[2] is 'LATEST'
    flowRefOk = flowRefOk and flowRef.length is 3

    if not flowRefOk
        response.setHeader 'Warning', "199 Invalid parameter flowRef #{flowRefStr}"
        response.statusCode = 400
        return


parseKey = (keyStr, dataQuery, dataset, response) ->
    dataQuery.codes = []

    if keyStr?
        keys = keyStr.split '.'

        if keys.length isnt dataset.codes.length - 1
            response.setHeader 'Warning', "199 Invalid number of dimensions in parameter key"
            response.statusCode = 400
            return

        for key, i in keys
            codes = key.split '+'
            dataQuery.codes[i] = []
            if codes.length is 1 and codes[0].length is 0
                for code, j in dataset.codes[i]
                    dataQuery.codes[i].push j
            else
                for code in codes 
                    index = dataset.codes[i].indexOf code
                    dataQuery.codes[i].push index if 0 <= index
    else
        for i in [0..dataset.codes.length-2] 
            dataQuery.codes[i] = []
            for j in [0..dataset.codes[i].length-1]
                dataQuery.codes[i].push j


parseProviderRef = (providerRefStr, dataQuery, response) ->
    if providerRefStr?
        providerRef = providerRefStr.split ','

        switch providerRef.length
            when 1
                if providerRef[0] is 'all'
                    providerRef[1] = 'ALL'
                else
                    providerRef[1] = providerRef[0]
                providerRef[0] = 'ALL'

        providerRefOk = providerRef.length is 1
        providerRefOk = providerRefOk and providerRef[0] is 'ECB' or providerRef[0] is 'ALL'
        providerRefOk = providerRef[1] is 'ECB' or providerRef[1] is 'ALL'

        if not providerRefOk
            response.setHeader 'Warning', "199 Invalid parameter providerRef #{providerRefStr}"
            response.statusCode = 400
            return


parseQueryParameters = (parameters, dataQuery, dataset, response) ->
    for param, value of parameters
        switch param
            when 'startPeriod', 'endPeriod'
                date = parseDate value, (param is 'endPeriod')
                if date?
                    dataQuery[param] = date
                    continue
            when 'firstNObservations', 'lastNObservations'
                n = ~Number(value)
                if String(n) is value and n >= 0
                    dataQuery[param] = n
                    continue
            when 'updatedAfter'
                response.statusCode = 501
                return
            when 'dimensionAtObservation'
                continue
            when 'detail'
                switch value
                    when 'full', 'dataonly', 'nodata'
                        dataQuery.detail = value
                        continue
                    when 'serieskeysonly'
                        response.statusCode = 501
                        return

        response.setHeader 'Warning', "199 Invalid query parameter #{param} value #{value}"
        response.statusCode = 400  
        return


# Main parsing function
parseUrl = (requestUrl, response) ->
    dataQuery = {}
    
    parsedUrl = url.parse requestUrl, yes
    path = parsedUrl.pathname.split '/'

    if path[1] isnt 'data'
        response.statusCode = 501
        return

    parseFlowRef path[2], dataQuery, response
    return unless response.statusCode is 200
 
    parseKey path[3], dataQuery, dataset, response
    return unless response.statusCode is 200

    parseProviderRef path[4], dataQuery, response
    return unless response.statusCode is 200

    parseQueryParameters parsedUrl.query, dataQuery, dataset, response
    return unless response.statusCode is 200

    dataQuery

#-------------------------------------------------------------------------------
# Functions for querying the sample data set

# Applies the date parameters to the codes in the time dimension
queryTimeDimension = (query, dataset) ->
    periods = []

    for period, i in dataset.codes[ dataset.codes.length - 1]
        if query.startPeriod?
            startDate = parseDate period, false
            continue unless query.startPeriod <= startDate
        if query.endPeriod?
            endDate = parseDate period, true
            continue unless endDate <= query.endPeriod
        periods.push i

    query.codes.push periods


# Recursive function that loops over each query dimension combination
# and returns all non-missing observation indices
findMatchingObsIndices = (key, keyPosition, queryResult, query, dataset) ->
    # Check if we are in the last dimension
    if keyPosition is query.length - 1
        obsCount = 0

        # Loop over codes in the last dimension
        for codeIndex, i in query[keyPosition]
            # Set the code in the last dimension
            key[keyPosition] = codeIndex

            # Calculate observation index for the combination of dimension values
            index = 0
            for multiplier, j in dataset.indexMultipliers
                index += key[j] * multiplier

            # Check if we have an observation in the current index
            if dataset.data[index]?
                # We have a non-missing observation
                # Loop over the dimension in the key
                for codeIndex, j in key
                    # Store the codes in key
                    queryResult.codes[j][codeIndex] = 1
                # Store the index
                queryResult.obsIndices.push index
                obsCount += 1

        return

    # We are not yet in the last dimension
    # Loop over codes in the current dimensions
    for codeIndex, i in query[keyPosition]
        key[keyPosition] = codeIndex
        # Move to next dimension
        findMatchingObsIndices key, keyPosition+1, queryResult, query, dataset


# Main query function. It finds matching observations, maps
# dimension code positions and creates the result data and code arrays. 
queryData = (query, dataset, response) ->
    queryTmpResult = 
        codes: []
        obsIndices: []

    queryTimeDimension query, dataset

    for dim in dataset.codes
        queryTmpResult.codes.push {}

    findMatchingObsIndices [], 0, queryTmpResult, query.codes, dataset

    queryResult =
        codes: []
        data: []
    codeIndexMapping = []

    for dim, i in queryTmpResult.codes
        queryResult.codes[i] = []
        codeIndexMapping[i] = []
        for codeIndex, j in Object.keys(dim).sort()
            codeIndexMapping[i][codeIndex] = j
            queryResult.codes[i][j] = dataset.codes[i][codeIndex]

    resultIndexMultipliers = calculateIndexMultipliers queryResult.codes

    for index in queryTmpResult.obsIndices
        newIndex = 0
        remainder = index
        for mult, i in dataset.indexMultipliers
            codeIndex = Math.floor( remainder / mult )
            remainder = remainder - ( codeIndex * mult )
            newIndex += codeIndexMapping[i][codeIndex] * resultIndexMultipliers[i]
        queryResult.data[newIndex] = dataset.data[index]

    if query.detail is 'nodata'
        delete queryResult.data

    queryResult

#-------------------------------------------------------------------------------
# Main function for handling HTTP requests

handleRequest = (request, response) ->
    response.setHeader 'Server', "#{SERVER_NAME}/#{SERVER_VERSION}"
    response.setHeader 'Cache-Control', 'no-cache, no-store'
    response.setHeader 'Pragma', 'no-cache'
    response.setHeader 'Access-Control-Allow-Origin', '*'
    response.statusCode = 200

    if not (request.method is 'GET' or request.method is 'HEAD')
        response.statusCode = 405
        response.setHeader 'Allow', 'GET, HEAD'
  
    if response.statusCode is 200
        dataQuery = parseUrl request.url, response

    if response.statusCode is 200
        data = queryData dataQuery, dataset, response

    if response.statusCode is 200
        response.setHeader 'Content-Type', 'application/json'

        if request.method is 'GET'
            response.end JSON.stringify data, null, 2
    
    response.end()

    log "#{request.method} #{request.url} #{response.statusCode}"

#-------------------------------------------------------------------------------
# Initialise and start the server

log 'starting'

# Load data set from file
dataset = loadDataset DATA_FILE

# Start an HTTP server
http.createServer( handleRequest ).listen PORT_NUMBER

log "listening on port #{PORT_NUMBER}"
