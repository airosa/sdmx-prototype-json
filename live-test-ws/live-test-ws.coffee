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

parseFlowRef = (flowRefStr, query, response) ->
    if not flowRefStr? 
        response.errors.push 'Mandatory parameter flowRef is missing'
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
        response.errors.push "Invalid parameter flowRef #{flowRefStr}"
        response.statusCode = 400
        return

    query.flowRef =
        agencyID: flowRef[0]
        id: flowRef[1]
        version: flowRef[2]


parseKey = (keyStr, query, dataset, response) ->
    keyStr = 'all' unless keyStr? 

    if keyStr is 'all'
        query.key = 'all'
        return

    query.key = []
    keys = keyStr.split '.'

    if keys.length isnt dataset.codes.length - 1
        response.errors.push "Invalid number of dimensions in parameter key"
        response.statusCode = 400
        return

    for key, i in keys
        query.key[i] = key.split '+'


parseProviderRef = (providerRefStr, query, response) ->
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
            response.errors.push "Invalid parameter providerRef #{providerRefStr}"
            response.statusCode = 400
            return

        query.providerRef =
            agencyID: providerRef[0]
            id: providerRef[1]


parseQueryParameters = (parameters, query, response) ->
    for param, value of parameters
        switch param
            when 'startPeriod', 'endPeriod'
                date = parseDate value, (param is 'endPeriod')
                if date?
                    query[param] = date
                    continue
            when 'firstNObservations', 'lastNObservations'
                n = ~Number(value)
                if String(n) is value and n >= 0
                    query[param] = n
                    continue
            when 'updatedAfter'
                response.statusCode = 501
                return
            when 'dimensionAtObservation'
                continue
            when 'detail'
                switch value
                    when 'full', 'dataonly', 'nodata'
                        query.detail = value
                        continue
                    when 'serieskeysonly'
                        response.statusCode = 501
                        return

        response.errors.push "Invalid query parameter #{param} value #{value}"
        response.statusCode = 400  
        return


parseDataQuery = (request, response) ->
    path = request.parsedUrl.pathname.split '/'

    parseFlowRef path[2], request.query, response
    return unless response.statusCode is 200
 
    parseKey path[3], request.query, dataset, response
    return unless response.statusCode is 200

    parseProviderRef path[4], request.query, response
    return unless response.statusCode is 200

    parseQueryParameters request.parsedUrl.query, request.query, response
    return unless response.statusCode is 200


# Main parsing function
parse = (request, response) ->
    request.query = {} 
    request.parsedUrl = url.parse request.url, yes

    path = request.parsedUrl.pathname.split '/'
    request.query.resource = path[1]

    switch request.query.resource
        when 'data'
            parseDataQuery request, response
        else
            response.statusCode = 501
            return

#-------------------------------------------------------------------------------
# Functions for querying the sample data set

addCodesToQuery = (request, codes, query) ->
    if request.query.key is 'all'
        for i in [0..codes.length-2] 
            query[i] = []
            for j in [0..codes[i].length-1]
                query[i].push j
        return

    for keyCodes, i in request.query.key
        query[i] = []
        if keyCodes.length is 1 and keyCodes[0].length is 0
            for code, j in codes[i]
                query[i].push j
        else
            for code in keyCodes
                index = codes[i].indexOf code
                query[i].push index if 0 <= index


# Applies the date parameters to the codes in the time dimension
addPeriodsToQuery = (request, periods, query) ->
    filteredPeriods = []

    for period, i in periods
        if request.query.startPeriod?
            startDate = parseDate period, false
            continue unless request.query.startPeriod <= startDate
        if request.query.endPeriod?
            endDate = parseDate period, true
            continue unless endDate <= request.query.endPeriod
        filteredPeriods.push i

    query.push filteredPeriods


# Recursive function that loops over each query dimension combination
# and returns all non-missing observation indices
findMatchingObsIndices = (key, keyPosition, query, dataset, result) ->
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
                    result.codeIndices[j][codeIndex] = 1
                # Store the index
                result.obsIndices.push index
                obsCount += 1

        return

    # We are not yet in the last dimension
    # Loop over codes in the current dimensions
    for codeIndex, i in query[keyPosition]
        key[keyPosition] = codeIndex
        # Move to next dimension
        findMatchingObsIndices key, keyPosition+1, query, dataset, result


# Main query function. It finds matching observations, maps
# dimension code positions and creates the result data and code arrays. 
query = (dataset, request, response) ->
    codesInQuery = []

    addCodesToQuery request, dataset.codes, codesInQuery
    addPeriodsToQuery request, dataset.codes[ dataset.codes.length - 1 ], codesInQuery

    firstResult = 
        codeIndices: []
        obsIndices: []

    for dim in codesInQuery
        firstResult.codeIndices.push {}

    # Find code and data indices for result
    findMatchingObsIndices [], 0, codesInQuery, dataset, firstResult

    codeIndexMapping = []

    # Add codes to result
    response.result.codes = []
    for indices, i in firstResult.codeIndices
        response.result.codes[i] = []
        codeIndexMapping[i] = []
        for codeIndex, j in Object.keys(indices).sort()
            codeIndexMapping[i][codeIndex] = j
            response.result.codes[i][j] = dataset.codes[i][codeIndex]

    return if request.query.detail is 'nodata'

    resultIndexMultipliers = calculateIndexMultipliers response.result.codes

    # Add data to result
    response.result.data = []
    for index in firstResult.obsIndices
        newIndex = 0
        remainder = index
        for mult, i in dataset.indexMultipliers
            codeIndex = Math.floor( remainder / mult )
            remainder = remainder - ( codeIndex * mult )
            newIndex += codeIndexMapping[i][codeIndex] * resultIndexMultipliers[i]
        response.result.data[newIndex] = dataset.data[index]

#-------------------------------------------------------------------------------
# Main function for handling HTTP requests

handleRequest = (request, response) ->
    response.setHeader 'Server', "#{SERVER_NAME}/#{SERVER_VERSION}"
    response.setHeader 'Cache-Control', 'no-cache, no-store'
    response.setHeader 'Pragma', 'no-cache'
    response.setHeader 'Access-Control-Allow-Origin', '*'
    response.setHeader 'Content-Type', 'application/json'
    response.errors = []
    response.result = {}
    response.statusCode = 200

    if not (request.method is 'GET' or request.method is 'HEAD')
        response.statusCode = 405
        response.setHeader 'Allow', 'GET, HEAD'
  
    if response.statusCode is 200
        parse request, response

    if response.statusCode is 200
        query dataset, request, response

    if response.statusCode is 200
        if request.method is 'GET'
            response.end JSON.stringify response.result, null, 2
        else # HEAD
            response.end()
    else
        response.end JSON.stringify { error: response.errors }, null, 2

    log "#{request.method} #{request.url} #{response.statusCode}"

#-------------------------------------------------------------------------------
# Initialise and start the server

log 'starting'

# Load data set from file
dataset = loadDataset DATA_FILE

# Start an HTTP server
http.createServer( handleRequest ).listen PORT_NUMBER

log "listening on port #{PORT_NUMBER}"
