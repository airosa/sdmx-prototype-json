http = require 'http'
url = require 'url'
fs = require 'fs'
path = require 'path'
zlib = require 'zlib'

#-------------------------------------------------------------------------------
# Globals and constants

SERVER_NAME = 'LIVE-TEST-WS-4'
SERVER_VERSION = '0.5.8'
PORT_NUMBER = process.env.PORT or 8081
NODE_ENV = process.env.NODE_ENV or 'test'
DATA_FILE = 'hicp-coicop-inx-json-slice.json'

# HTTP Response Codes
HTTP_OK = 200
HTTP_BAD_REQUEST = 400
HTTP_UNAUTHORIZED = 401
HTTP_NOT_FOUND = 404
HTTP_METHOD_NOT_ALLOWED = 405
HTTP_NOT_ACCEPTABLE = 406
HTTP_INTERNAL_SERVER_ERROR = 500
HTTP_NOT_IMPLEMENTED = 501


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
    msg = JSON.parse jsonString
    preProcessMessage msg


preProcessMessage = (msg) ->
    str = msg.structure
    ext = str.extensions =
        componentMap: {}
        keyDimensions: []
        dimensions: []
        attributeMap: {}

    str.dimension ?= {}
    str.dimensions.dataSet ?= []
    str.dimensions.series ?= []
    str.dimensions.observation ?= []
    str.attributes ?= {}
    str.attributes.dataSet ?= []
    str.attributes.series ?= []
    str.attributes.observation ?= []

    for key, value of str.dimensions
        for dim in value
            ext.dimensions.push dim
            ext.componentMap[dim.id] = dim
            if dim.id is 'TIME_PERIOD'
                ext.timeDimension = dim
            else
                ext.keyDimensions.push dim

    for key, value of str.attributes
        for attr in value
            ext.attributeMap[attr.id] = attr
            ext.componentMap[attr.id] = attr

    ext.keyDimensions.sort (a,b) -> a.keyPosition > b.keyPosition

    msg


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
        response.statusCode = HTTP_BAD_REQUEST
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
        response.statusCode = HTTP_BAD_REQUEST
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
        response.statusCode = HTTP_BAD_REQUEST
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
            response.statusCode = HTTP_BAD_REQUEST
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
        response.statusCode = HTTP_BAD_REQUEST
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
        response.statusCode = HTTP_BAD_REQUEST
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
                if 0 < +value
                    request.query[param] = +value
                    continue
            when 'updatedAfter'
                response.statusCode = HTTP_NOT_IMPLEMENTED
                return
            when 'dimensionAtObservation'
                request.query[param] = value
                continue
            when 'detail'
                switch value
                    when 'full', 'dataonly', 'nodata', 'serieskeysonly'
                        request.query[param] = value
                        continue
            when 'extraParams'
                request.query.extraParams = value
                continue

        response.result.errors.push "Invalid query parameter #{param} value #{value}"
        response.statusCode = HTTP_BAD_REQUEST
        return


parseDataQuery = (path, request, response) ->
    parseFlowRef path[2], request, response
    return unless response.statusCode is HTTP_OK

    parseKey path[3], request, response
    return unless response.statusCode is HTTP_OK

    parseProviderRef path[4], request, response
    return unless response.statusCode is HTTP_OK

    parseQueryParams request, response
    return unless response.statusCode is HTTP_OK


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
            response.statusCode = HTTP_NOT_IMPLEMENTED
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
        response.statusCode = HTTP_NOT_FOUND
        response.result.errors.push "Data flow not found"
        return

    dataset

#-------------------------------------------------------------------------------
# Data format specific code

mapCodesInQuery = (request, response, msg) ->
    key = msg.structure.extensions.keyDimensions
    query = {}

    periods = {}
    timeDimension = msg.structure.extensions.timeDimension

    for period, j in timeDimension.values
        if request.query.startPeriod?
            startDate = parseDate period.id, false
            continue unless request.query.startPeriod <= startDate
        if request.query.endPeriod?
            endDate = parseDate period.id, true
            continue unless endDate <= request.query.endPeriod
        periods[j] = 1

    query[timeDimension.id] = periods


    # Special case, all codes for all dimensions are in
    if request.query.key is 'all'
        codePositions = {}
        for dim in key
            codePositions[j] = 1 for code, j in dim.values
            query[dim.id] = codePositions
        return query

    if request.query.key.length isnt key.length
        response.result.errors.push "Invalid number of dimensions in parameter key"
        response.statusCode = HTTP_BAD_REQUEST
        return

    # Normal query
    for keyCodes, i in request.query.key
        dim = key[i]
        codePositions = {}

        # Dimension was wildcarded in the key
        if keyCodes.length is 0
            for code, j in dim.values
                codePositions[j] = 1

            query[dim.id] = codePositions
            continue

        codeMap = {}
        codeMap[code.id] = j for code, j in dim.values

        for code in keyCodes
            codePositions[ if codeMap[code]? then codeMap[code] else -1 ] = 1

        query[dim.id] = codePositions

    query


# Main query function. It finds matching observations, maps
# dimension code positions and creates the result data and code arrays.
query = (msg, request, response) ->
    # shorthand for result
    rslt = response.result
    dimAtObs = request.query.dimensionAtObservation
    str = msg.structure

    #---------------------------------------------------------------------------
    # Check if we just send the whole dataset
    fullDataSet = true
    fullDataSet = fullDataSet and not request.query.startPeriod?
    fullDataSet = fullDataSet and not request.query.endPeriod?
    fullDataSet = fullDataSet and request.query.key is 'all'
    fullDataSet = fullDataSet and not request.query.detail?
    fullDataSet = fullDataSet and not dimAtObs?

    if fullDataSet
        rslt.dataSets = msg.dataSets
        rslt.structure = msg.structure
        return

    #---------------------------------------------------------------------------

    # check that the dimension at obs makes sense
    if dimAtObs? and dimAtObs isnt 'AllDimensions'
        if not msg.structure.extensions.dimensions.some( (dim) -> dim.id is dimAtObs )
            response.statusCode = HTTP_BAD_REQUEST
            response.result.errors.push "Invalid value for parameter dimensionAtObservation #{dimAtObs}"
            return

    #---------------------------------------------------------------------------

    # Start collectiong the matching dimension codes

    codesInQuery = mapCodesInQuery request, response, msg
    return unless response.statusCode is HTTP_OK

    #---------------------------------------------------------------------------

    # We have matching codes. Start filtering series and observations.

    componentValuesInResults = {}

    # check the detail
    noObservations = false
    noAttributes = false
    switch request.query.detail
        when 'serieskeysonly'
            noObservations = true
            noAttributes = true
        when 'dataonly'
            noAttributes = true
        when 'nodata'
            noObservations = true

    for key, value of msg.structure.dimensions
        componentValuesInResults[comp.id] = {} for comp in value

    for key, value of msg.structure.attributes
        componentValuesInResults[comp.id] = {} for comp in value


    filterDataSet = (dataSet) ->
        return false if dataSet.dataSetAction is 'Delete'
        return true if str.dimensions.dataSet.length is 0

        for value, i in dataSet.dimensions
            dimId = str.dimensions.dataSet[i].id
            return false unless codesInQuery[dimId][value]?
            componentValuesInResults[dimId][value] = 1

        for value, i in dataSet.attributes when value?
            dimId = str.attributes.dataSet[i].id
            componentValuesInResults[dimId][value] = 1

        true


    filterSeries = (series) ->
        return false unless series.observations?

        for value, i in series.dimensions
            dimId = str.dimensions.series[i].id
            return false unless codesInQuery[dimId][value]?

        for value, i in series.dimensions
            dimId = str.dimensions.series[i].id
            componentValuesInResults[dimId][value] = 1

        for value, i in series.attributes when value?
            dimId = str.attributes.series[i].id
            componentValuesInResults[dimId][value] = 1

        true


    filterObservations = (obs) ->
        for dim, i in str.dimensions.observation
            return false unless codesInQuery[dim.id][obs[i]]?

        for dim, i in str.dimensions.observation
            componentValuesInResults[dim.id][obs[i]] = 1

        pos = str.dimensions.observation.length + 1
        for dim, i in str.attributes.observation
            continue unless obs[pos+i]?
            componentValuesInResults[dim.id][ obs[pos+i] ] = 1

        true


    mapSeries = (series) ->
        result =
            dimensions: series.dimensions.slice()

        if series.attributes? and not noAttributes
            result.attributes = series.attributes.slice()

        if not noObservations
            result.observations = series.observations.filter(filterObservations).map (obs) -> obs.slice()

        result


    mapDataSetToResult = (dataSet) ->
        result =
            id: dataSet.id
            action: dataSet.action
            extracted: dataSet.extracted
            name: dataSet.name
            description: dataSet.description

        if dataSet.dimensions?
            result.dimensions = dataSet.dimensions.slice()

        if dataSet.attributes? and not noAttributes
            result.attributes = dataSet.attributes.slice()

        if dataSet.series?
            result.series = dataSet.series.filter(filterSeries).map(mapSeries)

        if dataSet.observations? and not noObservations
            result.observations = dataSet.observations.filter(filterObservations).map (obs) -> obs.slice()

        result

    resultDataSets = msg.dataSets.filter(filterDataSet).map(mapDataSetToResult)

    #---------------------------------------------------------------------------

    # Check that we have data after the filtering

    count = 0
    count += Object.keys(value).length for key, value of componentValuesInResults

    if count is 0
        response.statusCode = HTTP_NOT_FOUND
        response.result.errors.push 'Data not found'
        return

    #---------------------------------------------------------------------------

    # Start rebasing the dimension/attribute value indexes

    for key, value of componentValuesInResults
        counter = 0
        for key2, value2 of value
            value[key2] = counter
            counter += 1


    reBaseArray = (target, source, start) ->
        return unless target?
        start ?= 0
        for dim, i in source
            continue unless target[ start + i ]?
            target[ start + i ] = componentValuesInResults[dim.id][ target[ start + i] ]


    reBaseObservations = (obs) ->
        reBaseArray obs, str.dimensions.observation
        start = str.dimensions.observation.length + 1
        reBaseArray obs, str.attributes.observation, start
        obs


    reBaseSeries = (series) ->
        reBaseArray series.dimensions, str.dimensions.series
        reBaseArray series.attributes, str.attributes.series
        if series.observations?
            series.observations = series.observations.map reBaseObservations
        series


    reBaseDataSet = (dataSet) ->
        reBaseArray dataSet.dimensions, str.dimensions.dataSet
        reBaseArray dataSet.attributes, str.attributes.dataSet

        if dataSet.series?
            dataSet.series = dataSet.series.map reBaseSeries

        if dataSet.observations?
            dataSet.observations = dataSet.observations.map reBaseObservations

        dataSet


    rslt.dataSets = resultDataSets.map reBaseDataSet

    #---------------------------------------------------------------------------

    # Results are now ready

    # Start building the structure field with components and packaging

    mapComponent = (comp) ->
        resultComp =
            id: comp.id
            name: comp.name
            description: comp.description
            role: comp.role
            values: []

        for key, value of componentValuesInResults[comp.id]
            resultComp.values[value] = comp.values[key]

        resultComp


    rslt.structure =
        id: msg.structure.id
        href: msg.structure.href
        ref: msg.structure.ref
        dimensions: {}
        attributes: {}

    for key, components of msg.structure.dimensions
        comps = rslt.structure.dimensions[key] = []
        for comp in components when comp?
            continue if request.query.detail is 'serieskeysonly' and comp.id is 'TIME_PERIOD'
            comps.push mapComponent(comp)

    unless noAttributes
        for key, components of msg.structure.attributes
            rslt.structure.attributes[key] = components.map(mapComponent) #.filter( (a) -> 0 < a.values.length )

    #---------------------------------------------------------------------------

    # results are now ready. Lets check if we need to format the results.

    formatFlatDataSet = (ds) ->
        dimensions = ds.observations.map (o) -> o.splice 0, dimCount
        obsDims = dimensions.map (d) -> d.splice dimAtObsPos, 1

        createSeries = (d, i) ->
            series =
                dimensions: d
                observations: [ obsDims[i].concat ds.observations[i] ]
            series

        seriesTmp = dimensions.map createSeries
        seriesTmp.sort (a, b) -> if a.dimensions.every( (d, i) -> d <= b.dimensions[i] ) then -1 else 1

        prevSeries = seriesTmp[0]
        filteredSeries = []
        for series, i in seriesTmp when 0 < i
            if prevSeries.dimensions.every( (d, j) -> d is series.dimensions[j] )
                prevSeries.observations = prevSeries.observations.concat series.observations
            else
                filteredSeries.push prevSeries
                prevSeries = series
        filteredSeries.push prevSeries

        ds.series = filteredSeries
        delete ds.observations

    flattenDataSet = (ds) ->
        if ds.series?
            ds.observations = []
            ds.series.forEach(
                (s) ->
                    if s.observations?
                        ds.observations = ds.observations.concat s.observations.map((o) -> s.dimensions.concat o, s.attributes)
                    else if s.attributes?
                        ds.observations = ds.observations.concat [ s.dimensions.concat s.attributes ]
                    else
                        ds.observations = ds.observations.concat [ s.dimensions ]
            )
            delete ds.series

    indexObservations = (ds) ->
        observations = {}
        dimCount = rslt.structure.dimensions.observation.length
        for obs in ds.observations
            key = obs[0...dimCount].join ':'
            value = obs[dimCount..]
            observations[key] = value
        ds.observations = observations

    reformatResults = false
    newStr = rslt.structure

    if dimAtObs?
        if dimAtObs is 'AllDimensions'
            # Check if we have dimensions at series or dataset levels
            reformatResults = true if 0 < str.dimensions.dataSet.length
            reformatResults = true if 0 < str.dimensions.series.length
        else
            reformatResults = true if 1 < str.dimensions.series.length
            reformatResults = dimAtObs isnt str.dimensions.observation[0].id

    if reformatResults
        if dimAtObs is 'AllDimensions'
            newStr.dimensions =
                dataSet: []
                series: []
                observation: newStr.dimensions.dataSet.concat newStr.dimensions.series, newStr.dimensions.observation
            newStr.attributes =
                dataSet: newStr.attributes.dataSet
                series: []
                observation: newStr.attributes.observation.concat newStr.attributes.series
        else
            newStr.dimensions =
                dataSet: newStr.dimensions.dataSet.filter (d) -> d.id isnt dimAtObs
                series: newStr.dimensions.series.concat(newStr.dimensions.observation).filter (d) -> d.id isnt dimAtObs
                observation: newStr.dimensions.series.concat(newStr.dimensions.observation).filter (d) -> d.id is dimAtObs
            newStr.attributes =
                dataSet: newStr.attributes.dataSet
                series: newStr.attributes.series
                observation: newStr.attributes.observation

        dims = newStr.dimensions.dataSet.concat newStr.dimensions.series, newStr.dimensions.observation
        dimAtObsPos = dims.indexOf dimAtObs
        dimCount = dims.length

        rslt.dataSets.forEach flattenDataSet
        rslt.dataSets.forEach formatFlatDataSet unless dimAtObs is 'AllDimensions'
        rslt.dataSets.forEach indexObservations if dimAtObs is 'AllDimensions' and request.query.extraParams is 'index'

    #---------------------------------------------------------------------------

    # Check if we can move any attributes or dimensions to data set level

    compressStructure = (type) ->
        compress = type.series.map (d) -> d.values.length < 2
        type.dataSet = type.dataSet.concat type.series.filter( (d, i) -> compress[i] )
        type.series = type.series.filter (d, i) -> not compress[i]
        compress

    compressDims = compressStructure rslt.structure.dimensions
    compressAttrs = compressStructure rslt.structure.attributes

    compressDataSet = (dataSet) ->
        return unless  dataSet.series?
        dataSet.dimensions ?= []
        dataSet.dimensions = dataSet.dimensions.concat dataSet.series[0].dimensions.filter (d, i) -> compressDims[i]
        dataSet.series.forEach (s) -> s.dimensions = s.dimensions.filter (d, i) -> not compressDims[i]
        dataSet.attributes ?= []
        dataSet.attributes = dataSet.attributes.concat dataSet.series[0].attributes.filter (d, i) -> compressAttrs[i]
        dataSet.series.forEach (s) -> s.attributes = s.attributes.filter (d, i) -> not compressAttrs[i]

    rslt.dataSets.forEach compressDataSet

    return

#-------------------------------------------------------------------------------

validateRequest = (request, response) ->
    methods = [ 'GET', 'HEAD', 'OPTIONS' ]
    mediaTypes = [ 'application/json', 'application/*', '*/*' ]
    response.setHeader 'Allow', methods.join( ', ' )
    response.setHeader 'Access-Control-Allow-Methods', methods.join( ', ' )
    response.setHeader 'Access-Control-Allow-Credentials', 'true'

    if request.headers['origin']?
        response.setHeader 'Access-Control-Allow-Origin', request.headers['origin']
    else
        response.setHeader 'Access-Control-Allow-Origin', '*'

    if methods.indexOf( request.method ) is -1
        response.statusCode = HTTP_METHOD_NOT_ALLOWED
        response.result.errors.push 'Supported methods: ' + methods.join(', ')
        return

    if request.headers['accept']?
        matches = 0
        for type in mediaTypes
            matches += request.headers['accept'].indexOf(type) + 1
        if matches is 0
            response.statusCode = HTTP_NOT_ACCEPTABLE
            response.result.errors.push 'Supported media types: ' + mediaTypes.join(',')
            return

    encoding = request.headers['accept-encoding']
    if encoding?
        if encoding.match /\bdeflate\b/
            response.setHeader 'Content-Encoding', 'deflate'
        else if encoding.match /\bgzip\b/
            response.setHeader 'Content-Encoding', 'gzip'

    if request.headers['access-control-request-headers']?
        response.setHeader 'Access-Control-Allow-Headers', request.headers['access-control-request-headers']

    if request.method is 'GET'
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
                response.statusCode = HTTP_UNAUTHORIZED
                response.result.errors.push 'authorization required'
                return


compressResponse = (request, response) ->

    sendResponse = (err, body) ->
        if err?
            response.statusCode = HTTP_INTERNAL_SERVER_ERROR
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
    response.setHeader 'Server',                      "#{SERVER_NAME}/#{SERVER_VERSION}/#{NODE_ENV}"
    response.setHeader 'Cache-Control',               'no-cache, no-store'
    response.setHeader 'Pragma',                      'no-cache'
    response.setHeader 'Content-Type',                'application/json'
    response.setHeader 'Content-Language',            'en'
    response.statusCode = HTTP_OK
    response.result =
        'sdmx-proto-json': dataset['sdmx-proto-json']
        header:
            id: "IREF#{ process.hrtime()[0] }#{ process.hrtime()[1] }"
            test: if NODE_ENV is 'production' then false else true
            prepared: (new Date()).toISOString()
            sender:
                id: SERVER_NAME
                name: SERVER_NAME
        errors: []

    validateRequest request, response

    if response.statusCode is HTTP_OK
        parse request, response

    if response.statusCode is HTTP_OK
        dataflow = findDataFlow request, response

    if request.method is 'OPTIONS'
        response.setHeader 'Content-Length', 0
    else
        if response.statusCode is HTTP_OK
            query dataflow, request, response

        if response.statusCode is HTTP_OK
            response.result.header.name = dataset.header.name
            response.result.errors = null

    compressResponse request, response

#-------------------------------------------------------------------------------
# Test the server

test = () ->
    res =
        headers: []
        setHeader: (n, v) -> @headers[n] = v
        getHeader: (n) -> @headers[n]
        end: () ->

    req =
        method: 'GET'
        #url: '/data/ECB_ICP1/M.PT+FI.N.073000.4.INX?startPeriod=2009&endPeriod=2009&dimensionAtObservation=REF_AREA'
        url: '/data/ECB_ICP1/M.PT+FI.N.073000.4.INX?startPeriod=2009&endPeriod=2009'
        headers:
            accept: 'application/json'

    handleRequest req, res

    #console.log res
    #console.log JSON.stringify res.result.dataSets, null, 2

#-------------------------------------------------------------------------------
# Initialise and start the server

log 'starting'

process.on 'uncaughtException', (err) ->
    log err
    process.exit()

# Load data set from file
dataset = loadDataset path.join( path.dirname( fs.realpathSync(__filename)), DATA_FILE )

# Start an HTTP server
http.createServer( handleRequest ).listen PORT_NUMBER

log "listening on port #{PORT_NUMBER}"

log 'Warning: This server is not designed for a production environment' if NODE_ENV is 'production'

#test()
