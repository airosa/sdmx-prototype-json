http = require 'http'
url = require 'url'
fs = require 'fs'

#-------------------------------------------------------------------------------
# Globals and constants

SERVER_NAME = 'LIVE-TEST-WS'
SERVER_VERSION = '0.1'
PORT_NUMBER = process.env.PORT or 8081
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
    #data.indexMultipliers = calculateIndexMultipliers data.codes
    data

#-------------------------------------------------------------------------------
# Functions for date processing

# Parses dates in reporting period format e.g. 2010-Q1
# Returns a date object set to the beginning of the reporting period.
# if end is true return the beginning of the next period
exports.timePeriodToDate = timePeriodToDate = (frequency, year, period, end) ->
    return null if year % 1 isnt 0
    return null if period % 1 isnt 0
    return null if period < 1

    date = new Date Date.UTC(year,0,1,0,0,0)
    period = period - 1 unless end

    switch frequency
        when 'A'
            return null if 1 < period
            date.setUTCMonth date.getUTCMonth() + (12 * period)
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
exports.parseDate = parseDate = (value, end) ->
    date = null

    if /^\d\d\d\d-[A|S|T|Q]\d$/.test value
        date = timePeriodToDate value[5], +value[0..3], +value[6], end
    else if /^\d\d\d\d-[M|W]\d\d$/.test value
        date = timePeriodToDate value[5], +value[0..3], +value[6..7], end
    else if /^\d\d\d\d-D\d\d\d$/.test value
        date = timePeriodToDate value[5], +value[0..3], +value[6..8], end
    else # give up on pattern matching and assume it is a date in ISO format
        millisecs = Date.parse value
        return null if isNaN millisecs
        date = new Date millisecs
        if end
            switch value.length
                when 4 then date.setUTCFullYear date.getUTCFullYear() + 1
                when 7 then date.setUTCMonth date.getUTCMonth() + 1
                when 10 then date.setUTCDate date.getUTCDate() + 1
    
    date.setUTCSeconds date.getUTCSeconds() - 1 if date? and end 

    date

#-------------------------------------------------------------------------------
# Functions for parsing the request url

exports.parseFlowRef = parseFlowRef = (flowRefStr, request, response) ->
    if not flowRefStr? 
        response.result.error.push 'Mandatory parameter flowRef is missing'
        response.statusCode = 400
        return

    regex = ///
        ^(
            ([A-z0-9_@$\-]+)
            |(([A-z][A-z0-9_\-]*(\.[A-z][A-z0-9_\-]*)*)
            (\,[A-z0-9_@$\-]+)
            (\,(latest|([0-9]+(\.[0-9]+)*)))?)
        )$
    ///

    if not regex.test flowRefStr
        response.result.error.push "Invalid parameter flowRef #{flowRefStr}"
        response.statusCode = 400
        return        

    flowRef = flowRefStr.split ','

    if flowRef.length is 1
        flowRef[1] = flowRef[0]
        flowRef[0] = 'all'

    flowRef[2] = 'latest' if not flowRef[2]? or flowRef[2] is ''

    request.query.flowRef =
        agencyID: flowRef[0]
        id: flowRef[1]
        version: flowRef[2]


exports.parseKey = parseKey = (keyStr, request, response) ->
    keyStr = 'all' unless keyStr? 

    if keyStr is 'all'
        request.query.key = 'all'
        return

    regex = ///
        ^(
            (
                [A-Za-z0-9_@$\-]+
                (
                    [+]
                    [A-Za-z0-9_@$\-]+
                )*
            )?
            (
                [.]
                (
                    [A-Za-z0-9_@$\-]+
                    (
                        [+]
                        [A-Za-z0-9_@$\-]+
                    )*
                )?
            )*
        )$
    ///

    if not regex.test keyStr
        response.result.error.push "Invalid parameter flowRef #{keyStr}"
        response.statusCode = 400
        return        

    key = []

    dims = keyStr.split '.'
    for dim, i in dims
        codes = dim.split '+'
        
        key[i] = []
        for code in codes when code isnt ''
            key[i].push code

        if -1 < dim.indexOf('+') and key[i].length is 0
            response.result.error.push "Invalid parameter key #{keyStr}"
            response.statusCode = 400
            return

    request.query.key = key


exports.parseProviderRef = parseProviderRef = (providerRefStr, request, response) ->
    providerRefStr = 'all' unless providerRefStr? 

    regex = ///
        ^(
            ([A-z][A-z0-9_\-]*(\.[A-z][A-z0-9_\-]*)*\,)?([A-z0-9_@$\-]+)
        )$
    ///

    if not regex.test providerRefStr
        response.result.error.push "Invalid parameter providerRef #{providerRefStr}"
        response.statusCode = 400
        return        

    providerRef = providerRefStr.split ','

    switch providerRef.length
        when 1
            if providerRef[0] isnt 'all'
                providerRef[1] = providerRef[0]
                providerRef[0] = 'all'

    providerRef[0] = 'all' if not providerRef[0]? or providerRef[0] is ''
    providerRef[1] = 'all' if not providerRef[1]? or providerRef[1] is ''

    if providerRef.length isnt 2
        response.result.error.push "Invalid parameter providerRef #{providerRefStr}"
        response.statusCode = 400
        return

    request.query.providerRef =
        agencyID: providerRef[0]
        id: providerRef[1]


exports.parseQueryParams = parseQueryParams = (request, response) ->
    parameters = url.parse( request.url, yes, no).query

    for param, value of parameters
        switch param
            when 'startPeriod', 'endPeriod'
                date = parseDate value, (param is 'endPeriod')
                if date?
                    request.query[param] = date
                    continue
            when 'firstNObservations', 'lastNObservations'
                n = ~Number(value)
                if String(n) is value and n >= 0
                    request.query[param] = n
                    continue
            when 'updatedAfter'
                response.statusCode = 501
                return
            when 'dimensionAtObservation'
                continue
            when 'detail'
                switch value
                    when 'full', 'dataonly', 'nodata'
                        request.query.detail = value
                        continue
                    when 'serieskeysonly'
                        response.statusCode = 501
                        return

        response.result.error.push "Invalid query parameter #{param} value #{value}"
        response.statusCode = 400  
        return


parseDataQuery = (path, request, response) ->
    parseFlowRef path[2], request, response
    return unless response.statusCode is 200
 
    parseKey path[3], request, response
    return unless response.statusCode is 200

    parseProviderRef path[4], request, response
    return unless response.statusCode is 200

    parseQueryParams request, response
    return unless response.statusCode is 200


# Main parsing function
parse = (request, response) ->
    request.query = {} 
    path = url.parse( request.url, no, no).pathname.split '/'
    
    request.query.resource = path[1]
    switch request.query.resource
        when 'data'
            parseDataQuery path, request, response
        else
            response.statusCode = 501
            return

#-------------------------------------------------------------------------------
# Functions for querying the sample data set

findDataFlow = (request, response) ->
    found = yes

    found &= switch request.query.flowRef.agencyID
        when 'all', 'ECB' then true
        else false

    found &= switch request.query.flowRef.id
        when 'ECB_ICP1' then true
        else false

    found &= switch request.query.flowRef.version
        when 'latest' then true
        else false

    found &= switch request.query.providerRef.agencyID
        when 'ECB', 'all' then true
        else false

    found &= switch request.query.providerRef.id
        when 'ECB', 'all' then true
        else false

    if not found 
        response.statusCode = 404
        response.result.error.push "Data flow not found"
        return

    dataset


addCodesToQuery = (request, response, msg) ->
    query = []
    query.push [] for dim in msg.dimension.id

    # Applies the date parameters to the codes in the time dimension
    for dim, i in msg.dimension.id
        continue unless msg.dimension[dim].role is 'time'

        for period, j in msg.dimension[dim].code.id
            if request.query.startPeriod?
                startDate = parseDate period, false
                continue unless request.query.startPeriod <= startDate
            if request.query.endPeriod?
                endDate = parseDate period, true
                continue unless endDate <= request.query.endPeriod
            query[i].push j

        break

    # Special case, all codes for all dimensions are in
    if request.query.key is 'all'
        for dim, i in msg.dimension.id
            continue if msg.dimension[dim].role is 'time' 
            query[i].push j for code, j in msg.dimension[dim].code.id
        return

    if request.query.key.length isnt msg.dimension.id.length - 1
        response.result.error.push "Invalid number of dimensions in parameter key"
        response.statusCode = 400
        return

    # Normal query
    for keyCodes, i in request.query.key
        dim = msg.dimension.id[i]

        # Dimension was wildcarded in the key
        if keyCodes.length is 0
            for code, j in msg.dimension[dim].code.id
                query[i].push j
            continue
        
        for code in keyCodes
            index = msg.dimension[dim].code.index[code]
            query[i].push index if 0 <= index

        # What happens if there are no valid codes for a dimension?

    query


# Main query function. It finds matching observations, maps
# dimension code positions and creates the result data and code arrays. 
query = (msg, request, response) ->
    # shorthand for result
    rslt = response.result

    # build an array of codes for the query
    codesInQuery = addCodesToQuery request, response, msg

    # built up multipliers for accesing data in the message
    msgSize = 1
    msgMultipliers = []
    for dim in msg.dimension.id.slice().reverse()
        msgMultipliers.push msgSize
        msgSize *= msg.dimension[dim].code.size
    msgMultipliers.reverse()

    # enumerate all keys in the query, algorithm is from stackoverflow
    querySize = 1
    queryMultipliers = []
    codesWithData = []
    for codes in codesInQuery
        queryMultipliers.push querySize
        querySize *= codes.length
        codesWithData.push {}

    if querySize is 0
        response.statusCode = 404
        response.result.error.push 'Observations not found'
        return

    # magic loop
    matchingObs = 0
    for i in [0..querySize-1]
        key = []
        obsIndex = 0
        for codes, n in codesInQuery
            index = Math.floor( i / queryMultipliers[n] ) % codes.length
            key.push codes[ index ]
            obsIndex += codes[ index ] * msgMultipliers[n]

        # check if we have a value for thisi index
        continue unless msg.measure['OBS_VALUE'].value[obsIndex]?

        # Store codes with observations
        for pos, j in key
            codesWithData[j][pos] ?= 0
            codesWithData[j][pos] += 1

        matchingObs += 1

    if matchingObs is 0
        response.statusCode = 404
        response.result.error.push 'Observations not found'
        return

    # add dimensions to the response
    rslt.dimension = {}
    rslt.dimension.id = msg.dimension.id
    rslt.dimension.size = msg.dimension.id.length
    for dim, i in msg.dimension.id
        rslt.dimension[dim] = 
            code: 
                id: []
                index: {}
                name: {}
            name: msg.dimension[dim].name
            role: msg.dimension[dim].role

        for pos, j in Object.keys codesWithData[i]
            code = msg.dimension[dim].code.id[pos]
            rslt.dimension[dim].code.id.push code
            rslt.dimension[dim].code.index[code] = j
            rslt.dimension[dim].code.name[code] = msg.dimension[dim].code.name[code]

        rslt.dimension[dim].code.size = rslt.dimension[dim].code.id.length

    return if request.query.detail is 'nodata'

    # Build code mapping between codes in the response and codes in the
    # data set. 

    codeMap = []
    for dim, n in rslt.dimension.id
        map = []
        for code, m in rslt.dimension[dim].code.id
            map.push msg.dimension[dim].code.index[code]
        codeMap.push map

    # Add measures to response

    resultCount = 1 
    resultMultipliers = []
    for dim in rslt.dimension.id
        resultMultipliers.push resultCount
        resultCount *= rslt.dimension[dim].code.size

    for msr in msg.measure.id
        rslt.measure ?= id: []
        rslt.measure.id.push msr
        rslt.measure[msr] = 
            size: resultCount
            value: []
            name: msg.measure[msr].name

        # magic loop
        for i in [0..resultCount-1]
            obsIndex = 0
            for codes, n in codeMap
                index = Math.floor( i / resultMultipliers[n] ) % codes.length
                obsIndex += codes[index] * msgMultipliers[n]
            
            rslt.measure[msr].value[i] = msg.measure[msr].value[obsIndex]

    # Add attributes to response
    for attr in msg.attribute.id
        attrCodeMapping = []

        resultCount = 1
        resultMultipliers = []
        for dim in msg.attribute[attr].dimension
            dimPos = msg.dimension.id.indexOf dim
            attrCodeMapping.push codeMap[dimPos]
            resultMultipliers.push resultCount
            resultCount *= codeMap[dimPos].length

        msgCount = 1
        msgMultipliers = []
        for dim in msg.attribute[attr].dimension.slice().reverse()
            msgMultipliers.push msgCount
            msgCount *= msg.dimension[dim].code.size
        msgMultipliers.reverse()
        
        value = []
        for i in [0..resultCount-1]
            attrIndex = 0
            for codes, n in attrCodeMapping
                index = Math.floor( i / resultMultipliers[n] ) % codes.length
                attrIndex += codes[index] * msgMultipliers[n]

            continue unless msg.attribute[attr].value[attrIndex]?

            value[i] = msg.attribute[attr].value[attrIndex]

        # filter empty attributes from the response
        continue if value.length is 0 and msg.attribute[attr].default is null

        rslt.attribute ?= id: []
        rslt.attribute.id.push attr
        rslt.attribute[attr] =
            name: msg.attribute[attr].name
            mandatory: msg.attribute[attr].mandatory
            role: msg.attribute[attr].role
            dimension: msg.attribute[attr].dimension
            default: msg.attribute[attr].default
            value: value


#-------------------------------------------------------------------------------

validateRequest = (request, response) ->
    methods = [ 'GET', 'HEAD' ]
    mediaTypes = [ 'application/json', 'application/*', '*/*' ]

    if methods.indexOf( request.method ) is -1
        response.statusCode = 405
        response.setHeader 'Allow', methods.join( ',' )
        response.result.error.push 'Supported methods: ' + methods.join(',')
        return

    if request.headers['accept']?
        matches = 0
        for type in mediaTypes
            matches += request.headers['accept'].indexOf(type) + 1
        if matches is 0
            response.statusCode = 406
            response.result.error.push 'Supported media types: ' + mediaTypes.join(',')
            return

#-------------------------------------------------------------------------------
# Main function for handling HTTP requests

handleRequest = (request, response) ->
    start = new Date()

    response.setHeader 'X-Powered-By',                "Node.js/#{process.version}"
    response.setHeader 'Server',                      "#{SERVER_NAME}/#{SERVER_VERSION}"
    response.setHeader 'Cache-Control',               'no-cache, no-store'
    response.setHeader 'Pragma',                      'no-cache'
    response.setHeader 'Access-Control-Allow-Origin', '*'
    response.setHeader 'Content-Type',                'application/json'
    response.statusCode = 200
    response.result = 
        id: "IREF#{ process.hrtime()[0] }#{ process.hrtime()[1] }"
        test: true
        prepared: (new Date()).toISOString()
        error: []

    validateRequest request, response

    if response.statusCode is 200
        parse request, response

    if response.statusCode is 200
        dataflow = findDataFlow request, response

    if response.statusCode is 200
        query dataflow, request, response

    if response.statusCode is 200
        response.result.name = dataset.name
        response.result.error = null

    body = JSON.stringify response.result, null, 2

    response.setHeader 'Content-Length', Buffer.byteLength body
    response.setHeader 'X-Runtime', new Date() - start

    if request.method is 'GET'
        response.end body
    else # HEAD
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
