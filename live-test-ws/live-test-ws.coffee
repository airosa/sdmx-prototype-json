http = require 'http'
url = require 'url'
fs = require 'fs'
zlib = require 'zlib'

#-------------------------------------------------------------------------------
# Globals and constants

SERVER_NAME = 'LIVE-TEST-WS'
SERVER_VERSION = '0.2.10'
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
        response.result.errors.push 'Mandatory parameter flowRef is missing'
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
        response.result.errors.push "Invalid parameter flowRef #{flowRefStr}"
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
        response.result.errors.push "Invalid parameter flowRef #{keyStr}"
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
            response.result.errors.push "Invalid parameter key #{keyStr}"
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
        response.result.errors.push "Invalid parameter providerRef #{providerRefStr}"
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
        response.result.errors.push "Invalid parameter providerRef #{providerRefStr}"
        response.statusCode = 400
        return

    request.query.providerRef =
        agencyID: providerRef[0]
        id: providerRef[1]


exports.parseQueryParams = parseQueryParams = (request, response) ->
    parameters = url.parse( request.url, yes, no).query

    request.query.dimensionAtObservation = 'AllDimensions'

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
                request.query[param] = value
                continue
            when 'detail'
                switch value
                    when 'full', 'dataonly', 'nodata', 'serieskeysonly'
                        request.query[param] = value
                        continue

        response.result.errors.push "Invalid query parameter #{param} value #{value}"
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

    path.shift() if path[1] is 'auth'
    
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
        response.result.errors.push "Data flow not found"
        return

    dataset


addCodesToQuery = (request, response, msg) ->
    query = []
    query.push [] for dim in msg.dimensions.id

    # Applies the date parameters to the codes in the time dimension
    for dim, i in msg.dimensions.id
        continue unless msg.dimensions[dim].type is 'time'

        for period, j in msg.dimensions[dim].codes.id
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
        for dim, i in msg.dimensions.id
            continue if msg.dimensions[dim].type is 'time' 
            query[i].push j for code, j in msg.dimensions[dim].codes.id
        return query

    if request.query.key.length isnt msg.dimensions.id.length - 1
        response.result.errors.push "Invalid number of dimensions in parameter key"
        response.statusCode = 400
        return

    # Normal query
    for keyCodes, i in request.query.key
        dim = msg.dimensions.id[i]

        # Dimension was wildcarded in the key
        if keyCodes.length is 0
            for code, j in msg.dimensions[dim].codes.id
                query[i].push j
            continue
        
        for code in keyCodes
            continue unless msg.dimensions[dim].codes[code]?
            index = msg.dimensions[dim].codes[code].index
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
    return unless response.statusCode is 200

    # built up multipliers for accesing data in the message
    msgSize = 1
    msgMultipliers = []
    for dim in msg.dimensions.id.slice().reverse()
        msgMultipliers.push msgSize
        msgSize *= msg.dimensions[dim].codes.id.length
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
        response.result.errors.push 'Observations not found'
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

        # check if we have a value for this index
        continue unless msg.measure[obsIndex]?

        # Store codes with observations
        for pos, j in key
            codesWithData[j][pos] ?= 0
            codesWithData[j][pos] += 1

        matchingObs += 1

    if matchingObs is 0
        response.statusCode = 404
        response.result.errors.push 'Observations not found'
        return

    if request.query.dimensionAtObservation isnt 'AllDimensions'
        if msg.dimensions.id.indexOf(request.query.dimensionAtObservation) is -1
            response.statusCode = 400
            response.result.errors.push "Invalid value for parameter dimensionAtObservation #{request.query.dimensionAtObservation}"
            return

    # add dimensions to the response
    rslt.dimensions = 
        id: msg.dimensions.id
        size: []
        dimensionAtObservation: request.query.dimensionAtObservation

    for dim, i in msg.dimensions.id
        rslt.dimensions[dim] = 
            id: msg.dimensions[dim].id
            codes: 
                id: []
            name: msg.dimensions[dim].name
            type: msg.dimensions[dim].type
            role: msg.dimensions[dim].role
            index: i

        for pos, j in Object.keys codesWithData[i]
            code = msg.dimensions[dim].codes.id[pos]
            rslt.dimensions[dim].codes.id.push code            
            rslt.dimensions[dim].codes[code] =
                index: j
                id: msg.dimensions[dim].codes[code].id
                name: msg.dimensions[dim].codes[code].name

            if msg.dimensions[dim].codes[code].start?
                rslt.dimensions[dim].codes[code].start = msg.dimensions[dim].codes[code].start

            if msg.dimensions[dim].codes[code].end?
                rslt.dimensions[dim].codes[code].end = msg.dimensions[dim].codes[code].end

        rslt.dimensions.size[i] = rslt.dimensions[dim].codes.id.length
        
    return if request.query.detail is 'serieskeysonly'

    unless request.query.detail is 'nodata'
        # Build code mapping between codes in the response and codes in the
        # data set. 

        codeMap = []
        for dim, n in msg.dimensions.id
            map = []
            for code, m in rslt.dimensions[dim].codes.id
                map.push msg.dimensions[dim].codes[code].index
            codeMap.push map

        # Add measures to response

        resultCount = 1 
        resultMultipliers = []
        for dim in rslt.dimensions.id.slice().reverse()
            resultMultipliers.push resultCount
            resultCount *= rslt.dimensions[dim].codes.id.length
        resultMultipliers.reverse()

        rslt.measure = []

        # magic loop
        for i in [0..resultCount-1]
            obsIndex = 0
            for codes, n in codeMap
                index = Math.floor( i / resultMultipliers[n] ) % codes.length
                obsIndex += codes[index] * msgMultipliers[n]
            
            rslt.measure[i] = msg.measure[obsIndex]

    if rslt.dimensions.dimensionAtObservation isnt 'AllDimensions'
        # We need to pivot the measure array into subarrays

        pivot = []
        pivotDimPos = rslt.dimensions.id.indexOf rslt.dimensions.dimensionAtObservation
        resultCodeLengths = []
        pivotMultipliers = []
        pivotCount = 1
        for dim, n in rslt.dimensions.id
            resultCodeLengths.push rslt.dimensions[dim].codes.id.length
            continue if n is pivotDimPos
            pivotMultipliers[n] = pivotCount
            pivotCount *= rslt.dimensions[dim].codes.id.length

        # magic loop
        for i in [0..resultCount-1]
            obsIndex = 0
            pivotIndex = 0
            pivotSubIndex = 0
            for length, n in resultCodeLengths
                codeIndex = Math.floor( i / resultMultipliers[n] ) % length
                obsIndex += codeIndex * resultMultipliers[n]

                if n is pivotDimPos
                    pivotSubIndex = codeIndex
                else
                    pivotIndex += codeIndex * pivotMultipliers[n]
            
            if msg.measure[obsIndex]?
                pivot[pivotIndex] ?= []
                pivot[pivotIndex][pivotSubIndex] = rslt.measure[obsIndex]

        rslt.measure = pivot


    return if request.query.detail is 'dataonly'

    # Add attributes to response
    for attr in msg.attributes.id

        attrCodeMapping = []
        for dim in msg.attributes[attr].dimension
            dimPos = msg.dimensions.id.indexOf dim
            attrCodeMapping.push codeMap[dimPos]

        resultCount = 1 
        resultMultipliers = []
        for dim in msg.attributes[attr].dimension.slice().reverse()
            resultMultipliers.push resultCount
            resultCount *= rslt.dimensions[dim].codes.id.length
        resultMultipliers.reverse()

        msgCount = 1
        msgMultipliers = []
        for dim in msg.attributes[attr].dimension.slice().reverse()
            msgMultipliers.push msgCount
            msgCount *= msg.dimensions[dim].codes.id.length
        msgMultipliers.reverse()
        
        value = []
        for i in [0..resultCount-1]
            attrIndex = 0
            for codes, n in attrCodeMapping
                index = Math.floor( i / resultMultipliers[n] ) % codes.length
                attrIndex += codes[index] * msgMultipliers[n]

            continue unless msg.attributes[attr].value[attrIndex]?

            value[i] = msg.attributes[attr].value[attrIndex]

        # filter empty attributes from the response
        continue if value.length is 0 and msg.attributes[attr].default is null

        rslt.attributes ?= id: []
        rslt.attributes.id.push attr
        rslt.attributes[attr] =
            id: msg.attributes[attr].id
            name: msg.attributes[attr].name
            mandatory: msg.attributes[attr].mandatory
            role: msg.attributes[attr].role
            dimension: msg.attributes[attr].dimension
            default: msg.attributes[attr].default
            value: value
            codes: msg.attributes[attr].codes


#-------------------------------------------------------------------------------

validateRequest = (request, response) ->
    methods = [ 'GET', 'HEAD', 'OPTIONS' ]
    mediaTypes = [ 'application/json', 'application/*', '*/*' ]
    response.setHeader 'Allow', methods.join( ', ' )
    response.setHeader 'Access-Control-Allow-Methods', methods.join( ', ' )

    if methods.indexOf( request.method ) is -1
        response.statusCode = 405
        response.result.errors.push 'Supported methods: ' + methods.join(', ')
        return

    if request.headers['accept']?
        matches = 0
        for type in mediaTypes
            matches += request.headers['accept'].indexOf(type) + 1
        if matches is 0
            response.statusCode = 406
            response.result.errors.push 'Supported media types: ' + mediaTypes.join(',')
            return

    encoding = request.headers['accept-encoding']
    if encoding?
        if encoding.match /\bdeflate\b/
            response.setHeader 'Content-Encoding', 'deflate'
        else if encoding.match /\bgzip\b/
            response.setHeader 'Content-Encoding', 'gzip'

    if request.headers['access-control-request-headers']?
        response.setHeader 'access-control-allow-headers', request.headers['access-control-request-headers']

    path = url.parse( request.url, no, no).pathname.split '/'
    if path[1] is 'auth'
        # Following code is from stackoverflow
        header = request.headers['authorization'] or ''
        token = header.split(/\s+/).pop() or ''
        auth = new Buffer(token, 'base64').toString()
        parts = auth.split /:/
        username = parts[0]
        password = parts[1]

        if username isnt 'test' or password isnt 'test'
            response.setHeader 'WWW-Authenticate', 'BASIC realm="data/ECB,ECB_ICP1"'
            response.statusCode = 401
            response.result.errors.push 'authorization required'
            return


compressResponse = (request, response) ->

    sendResponse = (err, body) ->
        if err?
            response.statusCode = 500
            response.end()
            return

        response.setHeader 'X-Runtime', new Date() - response.start

        if body?
            if Buffer.isBuffer body
                response.setHeader 'Content-Length', body.length
            else
                response.setHeader 'Content-Length', Buffer.byteLength body

            if request.method is 'GET'
                response.end body
            else
                response.end()
        else
            response.setHeader 'Content-Length', 0
            response.end()

        encoding = response.getHeader 'Content-Encoding'
        encoding ?= ''
        log "#{request.method} #{request.url} #{response.statusCode} #{encoding}"
        return


    switch request.method
        when 'OPTIONS'
            sendResponse()
        when 'GET', 'HEAD'
            body = JSON.stringify response.result, null, 2
            switch response.getHeader 'Content-Encoding'
                when 'deflate'
                    zlib.deflate body, sendResponse
                when 'gzip'
                    zlib.gzip body, sendResponse
                else
                    sendResponse undefined, body


#-------------------------------------------------------------------------------
# Main function for handling HTTP requests

handleRequest = (request, response) ->
    response.start = new Date()

    response.setHeader 'X-Powered-By',                "Node.js/#{process.version}"
    response.setHeader 'Server',                      "#{SERVER_NAME}/#{SERVER_VERSION}"
    response.setHeader 'Cache-Control',               'no-cache, no-store'
    response.setHeader 'Pragma',                      'no-cache'
    response.setHeader 'Access-Control-Allow-Origin', '*'
    response.setHeader 'Content-Type',                'application/json'
    response.setHeader 'Content-Language',            'en'
    response.statusCode = 200
    response.result = 
        'sdmx-proto-json': dataset['sdmx-proto-json']
        id: "IREF#{ process.hrtime()[0] }#{ process.hrtime()[1] }"
        test: true
        prepared: (new Date()).toISOString()
        errors: []

    validateRequest request, response

    if response.statusCode is 200
        parse request, response

    if response.statusCode is 200
        dataflow = findDataFlow request, response

    if request.method is 'OPTIONS'
        response.setHeader 'Content-Length', 0
    else
        if response.statusCode is 200
            query dataflow, request, response

        if response.statusCode is 200
            response.result.name = dataset.name
            response.result.errors = null

    compressResponse request, response

#-------------------------------------------------------------------------------
# Initialise and start the server

log 'starting'

# Load data set from file
dataset = loadDataset DATA_FILE

# Start an HTTP server
http.createServer( handleRequest ).listen PORT_NUMBER

log "listening on port #{PORT_NUMBER}"
