http = require 'http'
url = require 'url'
fs = require 'fs'
path = require 'path'
zlib = require 'zlib'
util = require 'util'

#-------------------------------------------------------------------------------
# Globals and constants

SERVER_NAME = 'LIVE-TEST-WS-7'
SERVER_VERSION = '0.6.11'
PORT_NUMBER = process.env.PORT or 8081
NODE_ENV = process.env.NODE_ENV or 'test'
DATA_FILE = 'hicp-coicop-inx-sdmx.json'
FULL_RESPONSE_FILE = 'full-response.json'

# HTTP Response Codes
HTTP_OK = 200
HTTP_BAD_REQUEST = 400
HTTP_UNAUTHORIZED = 401
HTTP_NOT_FOUND = 404
HTTP_METHOD_NOT_ALLOWED = 405
HTTP_NOT_ACCEPTABLE = 406
HTTP_INTERNAL_SERVER_ERROR = 500
HTTP_NOT_IMPLEMENTED = 501

KEY_SEPARATOR = ':'

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

    flattenGrouppedDataSet = (ds) ->
        return if ds.observations?
        return unless ds.series?

        obsDimCount = str.dimensions.observation.length
        seriesDimCount = str.dimensions.series.length
        obsAttrCount = str.attributes.observation.length
        seriesAttrCount = str.attributes.series.length

        str.dimensions =
            dataSet: str.dimensions.dataSet
            series: []
            observation: str.dimensions.series.concat str.dimensions.observation
        str.attributes =
            dataSet: str.attributes.dataSet
            series: []
            observation: str.attributes.observation.concat str.attributes.series

        ds.observations = []
        for key in Object.keys(ds.series)
            seriesDims = key.split(KEY_SEPARATOR).map( (d) -> +d )
            series = ds.series[key]

            for obsKey in Object.keys(series.observations)
                obsDims = obsKey.split(KEY_SEPARATOR).map( (d) -> +d )

                newObs = new Array(seriesDimCount + obsDimCount + 1 + obsAttrCount + seriesAttrCount)

                newObs[i] = val for val, i in seriesDims
                newObs[i + seriesDimCount] = val for val, i in obsDims
                newObs[i + seriesDimCount + obsDimCount] = val for val, i in series.observations[obsKey]
                newObs[i + seriesDimCount + obsDimCount + 1 + obsAttrCount] = val for val, i in series.attributes

                ds.observations.push newObs

        delete ds.series


    flattenFlatDataSet = (ds) ->
        return unless ds.observations?

        observations = []
        for key in Object.keys(ds.observations)
            dims = key.split KEY_SEPARATOR

            newObs = new Array dims.length + 1 + str.attributes.observation.length

            newObs[i] = val for val, i in dims
            newObs[i + dims.length] = val for val, i in ds.observations[key]

            observations.push newObs

        ds.observations = observations


    msg.dataSets.forEach flattenFlatDataSet
    msg.dataSets.forEach flattenGrouppedDataSet

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
    request.query.resource = request.path[1]
    switch request.query.resource
        when 'data'
            parseDataQuery request.path, request, response
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


getDimensionAtObservation = (msg, request, response) ->
    dimAtObs = request.query.dimensionAtObservation

    return 'TIME_PERIOD' unless dimAtObs?
    return dimAtObs if dimAtObs is 'AllDimensions'

    if not msg.structure.extensions.dimensions.some( (dim) -> dim.id is dimAtObs )
        response.statusCode = HTTP_BAD_REQUEST
        response.result.errors.push "Invalid value for parameter dimensionAtObservation #{dimAtObs}"

    return dimAtObs


# Main query function. It finds matching observations, maps
# dimension code positions and creates the result data and code arrays.
query = (msg, request, response) ->
    # shorthand for result
    rslt = response.result
    str = msg.structure

    #---------------------------------------------------------------------------
    # check that the dimension at obs makes sense

    dimAtObs = getDimensionAtObservation msg, request
    return unless response.statusCode is HTTP_OK

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
    # Start collectiong the matching dimension codes

    codesInQuery = mapCodesInQuery request, response, msg
    return unless response.statusCode is HTTP_OK

    #---------------------------------------------------------------------------

    # We have matching codes. Start filtering observations.

    componentValuesInResults = {}

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


    mapDataSetToResult = (ds) ->
        result =
            id: ds.id
            action: ds.action
            extracted: ds.extracted
            name: ds.name
            description: ds.description
            dimensions: []
            attributes: []
            annotations: []

        result.dimensions = ds.dimensions.slice() if ds.dimensions?
        result.attributes = ds.attributes?.slice() if ds.attributes?
        result.observations = ds.observations?.filter(filterObservation).map(mapObservation)

        result


    filterObservation = (obs) ->
        for dim, i in str.dimensions.observation
            return false unless codesInQuery[dim.id][ obs[i] ]?
        true


    mapObservation = (obs) ->
        for dim, i in str.dimensions.observation
            componentValuesInResults[dim.id][ obs[i] ] = 1

        pos = str.dimensions.observation.length + 1
        for dim, i in str.attributes.observation
            continue unless obs[pos+i]?
            componentValuesInResults[dim.id][ obs[pos+i] ] = 1

        obs.slice()


    rslt.dataSets = msg.dataSets.filter(filterDataSet).map(mapDataSetToResult)

    #console.log util.inspect rslt.dataSets, depth: null

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


    rebaseArray = (target, source, start) ->
        return unless target?
        start ?= 0
        for dim, i in source
            pos = start + i
            continue unless target[pos]?
            target[pos] = componentValuesInResults[dim.id][ target[pos] ]


    rebaseObservation = (obs) ->
        rebaseArray obs, str.dimensions.observation
        rebaseArray obs, str.attributes.observation, str.dimensions.observation.length + 1


    rebaseDataSet = (ds) ->
        rebaseArray ds.dimensions, str.dimensions.dataSet
        rebaseArray ds.attributes, str.attributes.dataSet

        if ds.observations?
            ds.observations.forEach rebaseObservation


    rslt.dataSets.forEach rebaseDataSet

    #---------------------------------------------------------------------------

    # Results are now ready

    # Start building the structure field with components and packaging

    mapComponent = (comp) ->
        mappedComp =
            id: comp.id
            name: comp.name
            description: comp.description
            role: comp.role
            keyPosition: comp.keyPosition
            values: []

        for key, value of componentValuesInResults[comp.id]
            mappedComp.values[value] = comp.values[key]

        mappedComp


    rslt.structure =
        id: msg.structure.id
        href: msg.structure.href
        ref: msg.structure.ref
        dimensions: {}
        attributes: {}
        annotations: []

    for key, components of msg.structure.dimensions
        rslt.structure.dimensions[key] = components.map mapComponent

    for key, components of msg.structure.attributes
        rslt.structure.attributes[key] = components.map mapComponent

    #---------------------------------------------------------------------------

    # Remove empty attributes

    filterEmptyAttributes = (value, i) ->
        return true if i < (rslt.structure.dimensions.observation.length + 1)
        k = i - (rslt.structure.dimensions.observation.length + 1)
        return not emptyAttributes[k]

    emptyAttributes = rslt.structure.attributes.observation.map (attr, i) -> attr.values.length is 0
    rslt.structure.attributes.observation = rslt.structure.attributes.observation.filter (a,i) -> not emptyAttributes[i]
    rslt.dataSets.forEach( (ds) -> ds.observations = ds.observations.map( (o) -> o.filter(filterEmptyAttributes) ) )

    #---------------------------------------------------------------------------
    # Group dimensions from the observation level to dataset level

    findDimensionToGroup = (dim, i) ->
        return false if 1 < dim.values.length

        countNulls = (count, ds) -> count + ds.observations.reduce ( (c, o) -> c + (o[i] is null) ), 0
        nullCount = rslt.dataSets.reduce countNulls, 0
        return false if 0 < nullCount

        true


    filterGrouppedDimensions = (value, i) ->
        return true if dimGroupings.length < i
        return not dimGroupings[i]


    groupDimensions = (ds) ->
        ds.dimensions = ds.dimensions.concat dimGroupings.filter( (g) -> g ).map( () -> 0 )
        ds.observations = ds.observations.map( (o) -> o.filter( filterGrouppedDimensions ) )

    minObsCount = rslt.dataSets.map( (d) -> d.observations.length ).reduce( (x, y) -> if x < y then x else y )
    if 1 < minObsCount
        dimGroupings = rslt.structure.dimensions.observation.map findDimensionToGroup
        rslt.structure.dimensions.dataSet = rslt.structure.dimensions.dataSet.concat rslt.structure.dimensions.observation.filter( (d,i) -> dimGroupings[i] )
        rslt.structure.dimensions.observation = rslt.structure.dimensions.observation.filter( (d,i) -> not dimGroupings[i] )
        rslt.dataSets.forEach groupDimensions

    #---------------------------------------------------------------------------
    # Group attributes from the observation level to dataset level

    findAttributeToGroup = (attr, i) ->
        return false if 1 < attr.values.length

        k = rslt.structure.dimensions.observation.length + 1 + i

        countNulls = (count, ds) -> count + ds.observations.reduce ( (c, o) -> c + (o[k] is null) ), 0
        nullCount = rslt.dataSets.reduce countNulls, 0
        return false if 0 < nullCount

        true


    filterGrouppedAttributes = (value, i) ->
        return true if i < (rslt.structure.dimensions.observation.length + 1)
        k = i - (rslt.structure.dimensions.observation.length + 1)
        return not attrGroupings[k]


    groupAttributes = (ds) ->
        ds.attributes = ds.attributes.concat attrGroupings.filter( (g) -> g ).map( () -> 0 )
        ds.observations = ds.observations.map( (o) -> o.filter( filterGrouppedAttributes ) )


    attrGroupings = rslt.structure.attributes.observation.map findAttributeToGroup
    rslt.structure.attributes.dataSet = rslt.structure.attributes.dataSet.concat rslt.structure.attributes.observation.filter( (d,i) -> attrGroupings[i] )
    rslt.structure.attributes.observation = rslt.structure.attributes.observation.filter( (d,i) -> not attrGroupings[i] )
    rslt.dataSets.forEach groupAttributes

    #---------------------------------------------------------------------------
    # check the detail parameter

    switch request.query.detail
        when 'serieskeysonly'
            dropDimension = 'TIME_PERIOD'
            pos = rslt.structure.dimensions.dataSet.map( (d) -> d.id ).indexOf dropDimension
            if -1 < pos
                rslt.structure.dimensions.dataSet.splice pos, 1
                rslt.dataSets.forEach (ds) -> ds.dimensions.splice pos, 1
            else
                pos = rslt.structure.dimensions.observation.map( (d) -> d.id ).indexOf dropDimension
                if -1 < pos
                    rslt.structure.dimensions.observation.splice pos, 1
                    rslt.dataSets.forEach( (ds) -> ds.observations.forEach( (o) -> o.splice pos, 1 ) )

            rslt.structure.attributes.dataSet = []
            rslt.structure.attributes.series = []
            rslt.structure.attributes.observation = []

            obsDimCount = rslt.structure.dimensions.observation.length
            rslt.dataSets.forEach( (ds) -> ds.attributes = [])
            rslt.dataSets.forEach( (ds) -> ds.observations = ds.observations.map( (o) -> o.slice(0, obsDimCount) ) )
        when 'dataonly'
            rslt.structure.attributes.dataSet = []
            rslt.structure.attributes.series = []
            rslt.structure.attributes.observation = []

            obsDimCount = rslt.structure.dimensions.observation.length
            rslt.dataSets.forEach( (ds) -> ds.attributes = [])
            rslt.dataSets.forEach( (ds) -> ds.observations = ds.observations.map( (o) -> o.slice(0, obsDimCount + 1) ) )
        when 'nodata'
            pos = rslt.structure.dimensions.observation.length
            rslt.dataSets.forEach( (ds) -> ds.observations.forEach( (o) -> o.splice pos, 1 ) )

    #---------------------------------------------------------------------------

    # results are now ready. Lets check if we need to format the results.

    if dimAtObs isnt 'AllDimensions'
        obsDimCount = rslt.structure.dimensions.observation.length

        pos = rslt.structure.dimensions.dataSet.map( (d) -> d.id ).indexOf dimAtObs

        if -1 < pos
            # Oh no dimAtObs is at the dataset level
            rslt.structure.dimensions.series = rslt.structure.dimensions.observation
            rslt.structure.dimensions.observation = rslt.structure.dimensions.dataSet.splice pos, 1

            formatDataSet = (ds) ->
                mapObservation = (o) ->
                    return {
                        dimensions: o.slice(0, obsDimCount)
                        observations: [ [0].concat( o.slice(obsDimCount) ) ]
                        attributes: []
                    }

                ds.series = ds.observations.map mapObservation
                delete ds.observations

        else
            if obsDimCount is 1
                # We need to move the dataset level dimensions back to observation level
                rslt.structure.dimensions.observation = rslt.structure.dimensions.dataSet.concat rslt.structure.dimensions.observation
                rslt.structure.dimensions.dataSet = []

                unGroupDataSetDimensions = (ds) ->
                    ds.observations = ds.observations.map( (o) -> ds.dimensions.concat o )
                    ds.dimensions = []

                rslt.dataSets.forEach unGroupDataSetDimensions

                obsDimCount = rslt.structure.dimensions.observation.length

            pos = rslt.structure.dimensions.observation.map( (d) -> d.id ).indexOf dimAtObs
            rslt.structure.dimensions.series = rslt.structure.dimensions.observation
            rslt.structure.dimensions.observation = rslt.structure.dimensions.series.splice pos, 1

            formatDataSet = (ds) ->
                series = {}

                mapObservation = (o) ->
                    seriesDims = o.slice(0, obsDimCount)
                    obsDim = seriesDims.splice pos, 1
                    seriesKey = seriesDims.join KEY_SEPARATOR
                    series[seriesKey] ?=
                        dimensions: seriesDims
                        attributes: []
                        observations: []
                        annotations: []
                    series[seriesKey].observations.push obsDim.concat( o.slice(obsDimCount) )

                ds.observations.forEach mapObservation
                delete ds.observations

                # Check if we can group observation level attributes as series level

                groupObsAttr = []
                groupObsAttr.push true for attr in rslt.structure.attributes.observation

                for key, value of series
                    for test, i in groupObsAttr when test is true
                        k = i + 2
                        first = value.observations[0][k]
                        groupObsAttr[i] = value.observations.every (o) -> o[k] is first

                for test, i in groupObsAttr when test is true
                    rslt.structure.attributes.series.push rslt.structure.attributes.observation[i]

                filterGrouppedObsAttributes = (v, i) ->
                    return false if i < 2
                    groupObsAttr[i-2]

                filterNotGrouppedObsAttributes = (v, i) -> not filterGrouppedObsAttributes(v,i)

                for key, value of series
                    value.attributes = value.attributes.concat value.observations[0].filter( filterGrouppedObsAttributes )
                    value.observations = value.observations.map( (o) -> o.filter(filterNotGrouppedObsAttributes) )

                rslt.structure.attributes.observation = rslt.structure.attributes.observation.filter( (a, i) -> not groupObsAttr[i] )

                # Finally create the series objects

                ds.series = []
                for key, value of series
                    ds.series.push
                        dimensions: value.dimensions
                        attributes: value.attributes
                        observations: value.observations

        rslt.dataSets.forEach formatDataSet

    #---------------------------------------------------------------------------
    # Add index


    obsDimCount = rslt.structure.dimensions.observation.length
    if rslt.structure.dimensions.series.length is 0
        addIndices = (ds) ->
            observations = {}
            ds.observations.forEach (o) -> observations[ o.slice(0, obsDimCount).join(KEY_SEPARATOR) ] = o.slice(obsDimCount)
            ds.observations = observations
    else
        addIndices = (ds) ->
            series = {}

            addIndexToSeries = (s) ->
                observations = {}
                s.observations.forEach (o) -> observations[ o.slice(0, obsDimCount).join(KEY_SEPARATOR) ] = o.slice(obsDimCount)
                s.observations = observations
                series[ s.dimensions.join(KEY_SEPARATOR) ] = s
                delete s.dimensions

            ds.series.forEach addIndexToSeries
            ds.series = series

    rslt.dataSets.forEach addIndices

    #---------------------------------------------------------------------------
    # Remove dataset level dimensions

    rslt.dataSets.forEach (ds) -> delete ds.dimensions

    #---------------------------------------------------------------------------
    # Done

    return

#-------------------------------------------------------------------------------
# Return documentation

getDocs = (request, response) ->
    docs =
        main:
            Description: "Test server"
            Features:
                Parameters:
                    dimensionAtObservation: 'Supported, you can use AllDimensions or any dimension id. Default is TIME_PERIOD'
                    startPeriod: 'Supported, all time formats should work.'
                    endPeriod: 'Supported, same as startPeriod.'
                    firstNObservations: 'Not supported.'
                    lastNObservations: 'Not supported.'
                    detail: 'Supported, serieskeysonly, nodata, dataonly and full should work. Default is full.'
                    updatedAfter: 'Not supported.'
            'Data Flows':
                urls: [ 'docs/ECB_ICP1' ]
        ECB_ICP1:
            Description: "Test data"
            Size: ""
            Requests:
                'Data Flow':
                    Agency: 'ECB'
                    Identifier: 'ECB_ICP1'
                    Version: '1.0'
                'Key Dimensions': {}
                'Time Dimension': {}
                'Data Provider':
                    Agency: 'ECB'
                    Identifier: 'ECB'
            'Sample Requests':
                urls: [
                    '../data/ECB_ICP1/M.PT+FI.N.000000+071100.4.INX?startPeriod=2009-01&dimensionAtObservation=AllDimensions'
                    '../data/ECB_ICP1/M.AT.N.000000.4.INX?startPeriod=2003-06'
                    '../data/ECB_ICP1/M..N.0531_2.4.INX?startPeriod=2009-02&endPeriod=2009-02&dimensionAtObservation=REF_AREA'
                    '../data/ECB_ICP1/M..N.0531_2.4.INX?startPeriod=2009-01&dimensionAtObservation=REF_AREA'
                ]


    response.setHeader 'Content-Type', 'text/html'

    writeHTML = (values) ->
        body = []
        body.push '<!DOCTYPE html>'
        body.push '<html lang="en">'
        body.push '<head>'
        body.push '<link href="//netdna.bootstrapcdn.com/twitter-bootstrap/2.3.1/css/bootstrap-combined.min.css" rel="stylesheet">'
        body.push '</head>'
        body.push '<body>'
        body.push '<div class="container">'
        body.push '<div class="page-header">'
        body.push '<h1>Documentation</h1>'
        body.push '</div>'

        objectToHTML = (obj, level, index) ->
            count = 1
            heading = "h#{level}"
            for key, value of obj
                indexCur = index + count + '.'
                switch key
                    when 'urls'
                        body.push '<ul>'
                        for link in value
                            body.push "<li><a href='#{link}'>#{link}</a></li>"
                        body.push '</ul>'
                    else
                        if key[0] is '<'
                            body.push key
                        else
                            body.push "<#{heading}>#{indexCur} #{key}</#{heading}>"

                        switch typeof value
                            when 'object'
                                objectToHTML value, level + 1, "#{indexCur}"
                            else
                                if value[0] is '<'
                                    body.push value
                                else
                                    body.push "<p>#{value}</p>"

                body.push '<hr>' if level is 2
                count += 1

        objectToHTML values, 2, ''

        body.push '</div>'
        body.push '</body>'
        body.push '</html>'
        body.join ''


    documentDataFlow = (id) ->
        dfDocs = docs[id]

        if not dfDocs?
            response.statusCode = HTTP_NOT_FOUND
            return '<html>Not found</html>'

        obsCount = dataset.dataSets.reduce( ((x, y) -> x + y.observations.length), 0)
        cubeSize = 1
        cube = []
        for key, value of dataset.structure.dimensions
            for comp in value
                html = []

                html.push '<dl class="dl-horizontal">'
                html.push "<dt>ID</dt><dd>#{comp.id}</dd>"
                html.push "<dt>Name</dt><dd>#{comp.name}</dd>"
                html.push '<dt>Values</dt><dd>'
                html.push ("<abbr title='#{val.name}'>#{val.id}</abbr>" for val in comp.values).join ', '
                html.push '</dd>'
                html.push '</dl>'

                cube.push comp.values.length
                cubeSize *= comp.values.length

                if comp.role is 'time'
                    dfDocs.Requests['Time Dimension'][comp.name] = html.join ''
                else
                    dfDocs.Requests['Key Dimensions'][comp.name] = html.join ''

        full = Math.round(((obsCount / cubeSize) * 100))
        dfDocs.Size = "Total number of observations is #{obsCount}. Total size of the dimensions space is ( #{cube.join(' * ')} ) = #{cubeSize}. Cube is #{full}% full."

        writeHTML dfDocs


    if request.path[2]?
        return documentDataFlow request.path[2]
    else
        return writeHTML(docs.main)

#-------------------------------------------------------------------------------

validateRequest = (request, response) ->
    methods = [ 'GET', 'HEAD', 'OPTIONS' ]
    mediaTypes = [ 'application/json', 'application/*', '*/*' ]
    response.setHeader 'Allow', methods.join( ', ' )
    response.setHeader 'Access-Control-Allow-Methods', methods.join( ', ' )
    response.setHeader 'Access-Control-Allow-Credentials', 'true'
    response.setHeader 'Access-Control-Expose-Headers', 'X-Runtime, Content-Length'

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
        if encoding.match /\bgzip\b/
            response.setHeader 'Content-Encoding', 'gzip'
        else if encoding.match /\bdeflate\b/
            response.setHeader 'Content-Encoding', 'deflate'

    if request.headers['access-control-request-headers']?
        response.setHeader 'Access-Control-Allow-Headers', request.headers['access-control-request-headers']

    if request.method is 'GET'
        if request.path[1] is 'auth'
            request.path.shift()
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


compressResponse = (request, response, body) ->

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
    response.setHeader 'Content-Language',            'en'
    response.statusCode = HTTP_OK
    protocol = if request.connection.encrypted? then 'https://' else 'http://'

    request.path = url.parse( request.url, no, no).pathname.split '/'

    validateRequest request, response

    switch request.path[1]
        when 'data'
            response.setHeader 'Content-Type', 'application/json'
            response.result =
                'sdmx-proto-json': dataset['sdmx-proto-json']
                header:
                    id: "IREF#{ process.hrtime()[0] }#{ process.hrtime()[1] }"
                    test: if NODE_ENV is 'production' then false else true
                    prepared: (new Date()).toISOString()
                    sender:
                        id: SERVER_NAME
                        name: SERVER_NAME
                    request:
                        uri: "#{protocol}#{request.headers.host}#{request.url}"
                errors: []

            if request.url is '/data/ECB_ICP1/.....'
                body = fs.readFileSync FULL_RESPONSE_FILE
            else
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

                body = JSON.stringify response.result #, null, 2
        when 'docs'
            if request.method is 'OPTIONS'
                response.setHeader 'Content-Length', 0
            else
                body = getDocs request, response

    compressResponse request, response, body

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
        url: '/data/ECB_ICP1/M.PT+FI.N.073000.4.INX?startPeriod=2009&endPeriod=2009&dimensionAtObservation=AllDimensions'
        #url: '/data/ECB_ICP1/M.PT+FI.N.073000.4.INX?startPeriod=2009&endPeriod=2009'
        headers:
            accept: 'application/json'

    handleRequest req, res

    #console.log res
    #console.log JSON.stringify res.result.dataSets, null, 2

#-------------------------------------------------------------------------------
# Initialise and start the server

log 'starting'

#process.on 'uncaughtException', (err) ->
#    log err
#    process.exit()

# Load data set from file
dataset = loadDataset path.join( path.dirname( fs.realpathSync(__filename)), DATA_FILE )

# Start an HTTP server
server = http.createServer( handleRequest ).listen PORT_NUMBER

log "listening on port #{PORT_NUMBER}"

log 'Warning: This server is not designed for a production environment' if NODE_ENV is 'production'

#test()
