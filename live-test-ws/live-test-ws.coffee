http = require 'http'
url = require 'url'
fs = require 'fs'

#-------------------------------------------------------------------------------
# Globals and constants

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
    jsonString =  fs.readFileSync filename
    data = JSON.parse jsonString
    data.indexMultipliers = calculateIndexMultipliers data.codes
    data

#-------------------------------------------------------------------------------
# Functions for date processing

# Parses dates in reporting periof format e.g. 2010-Q1
# Returns a date object set to the beginning of the reporting period.
# if end is true return the beginning of the next period
parseReportingTimePeriod = (frequency, year, period, end) ->
    if year % 1 isnt 0 
        throw new Error "Invalid year value #{year}"

    if period % 1 isnt 0
        throw new Error "Invalid period value #{period}"

    date = new Date Date.UTC(year,0,1,0,0,0)
    period = period - 1 unless end
    switch frequency
        when 'A'
            date
        when 'S'
            if 0 < period and period < 3
                date.setUTCMonth date.getUTCMonth() + (6 * period)
            else
                throw new Error "Invalid period value #{period}"
        when 'T'
            if 0 < period and period < 4
                date.setUTCMonth date.getUTCMonth() + (4 * period)
            else
                throw new Error "Invalid period value #{period}"
        when 'Q'
            if 0 < period and period < 5
                date.setUTCMonth date.getUTCMonth() + (3 * period)
            else
                throw new Error "Invalid period value #{period}"
        when 'M'
            if 0 < period and period < 13
                date.setUTCMonth date.getUTCMonth() + period
            else
                throw new Error "Invalid period value #{period}"
        when 'W'
            if date.getUTCDay() isnt 4
                date.setUTCMonth 0, 1 + (((4 - date.getUTCDay()) + 7) % 7)
            date.setUTCDate date.getUTCDate() - 3
            date.setUTCDate date.getUTCDate() + (7 * period)
        when 'D'
            date.setUTCDate date.getUTCDate() + period
    date

# Parses dates in all supported formats. Format is detected from the value
# length. Returns date object set the beginning of the period. If end is true
# then returned date is set to the end of the period.
parseDate = (value, end) ->
    date = null

    try
        switch value.length
            when 4
                date = new Date Date.UTC(+value,0,1,0,0,0)
                if end
                    date.setUTCFullYear date.getUTCFullYear() + 1
            when 7
                switch value[5..5]
                    when 'A', 'S', 'T', 'Q'
                        date = parseReportingTimePeriod value[5..5], +value[0..3], +value[6..], end
                    else    
                        date = new Date Date.UTC(+value[0..3],+value[5..6]-1,1,0,0,0)
                        if end
                            date.setUTCMonth date.getUTCMonth() + 1
            when 8, 9
                date = parseReportingTimePeriod value[5..5], +value[0..3], +value[6..], end
            when 10
                date = new Date Date.UTC(+value[0..3],+value[5..6]-1,+value[8..9],0,0,0)
                if end 
                    date.setUTCDate date.getUTCDate() + 1
            when 19
                return Date.parse value, 'yyyy-MM-ddTHH:mm:ss'

        if end 
            date.setUTCSeconds date.getUTCSeconds() - 1
    catch error
        date = null

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

    periods = []

    if dataQuery.startPeriod? or dataQuery.endPeriod?
        for period, i in dataset.codes[ dataset.codes.length - 1]
            startDate = parseDate period, false
            endDate = parseDate period, true
            if dataQuery.startPeriod?
                continue unless dataQuery.startPeriod <= startDate
            if dataQuery.endPeriod?
                continue unless endDate <= dataQuery.endPeriod
            periods.push i
    else
        for period, i in dataset.codes[ dataset.codes.length - 1]
            periods.push i
    
    dataQuery.codes.push periods


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

# Recursive function that loops over each query dimension combination
# and returns all non-missing observation index
findMatchingObsIndices = (key, keyPosition, queryResult, query, dataset) ->
    if keyPosition is query.length - 1
        obsCount = 0
        for codeIndex, i in query[keyPosition]
            key[keyPosition] = codeIndex

            index = 0
            for multiplier, j in dataset.indexMultipliers
                index += key[j] * multiplier

            if dataset.data[index]?
                for codeIndex, j in key
                    queryResult.codes[j][codeIndex] = 1
                queryResult.obsIndices.push index
                obsCount += 1

        return

    for codeIndex, i in query[keyPosition]
        key[keyPosition] = codeIndex
        findMatchingObsIndices key, keyPosition+1, queryResult, query, dataset


# Main query function. It finds matching observation observations, maps
# dimensions code positions and creates the result data and code arrays. 
queryData = (query, response) ->
    queryTmpResult = 
        codes: []
        obsIndices: []

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
    log "request #{request.url} from #{request.connection.remoteAddress}"

    response.setHeader 'Server', 'SDMX-PROTOTYPE-JSON-TEST/0.1'
    response.setHeader 'Cache-Control', 'no-cache, no-store'
    response.setHeader 'Pragma', 'no-cache'
    response.setHeader 'Access-Control-Allow-Origin', '*'
    response.statusCode = 200

    if not (request.method is 'GET' or request.method is 'HEAD')
        response.statusCode = 405
        response.setHeader 'Allow', 'GET, HEAD'
        response.end()
        return

    dataQuery = parseUrl request.url, response

    if response.statusCode isnt 200
        response.end()
        return

    data = queryData dataQuery, response

    if response.statusCode isnt 200
        response.end()
        return

    response.setHeader 'Content-Type', 'application/json'

    if request.method is 'GET'
        response.end JSON.stringify data, null, 2
    else
        response.end()

    log "response #{response.statusCode}"

#-------------------------------------------------------------------------------
# Code to initialise and start the server

log 'starting'

# Load data set from file
dataset = loadDataset DATA_FILE

# Start an HTTP server
http.createServer( handleRequest ).listen PORT_NUMBER
log "listening on port #{PORT_NUMBER}"
