demoModule.controller 'MainCtrl', ($scope, $http) ->
    $scope.version = '0.2.0'

    $scope.state =
        httpError: false
        httpErrorData: false
        dataRequestRunning: false
        dimensionRequestRunning: false

    $scope.wsName = 'http://live-test-ws-2.nodejitsu.com'
    #$scope.wsName = 'http://localhost:8081'
    #$scope.wsName = 'http://46.137.144.117/FusionCube/ws'

    $scope.dfName = 'ECB_ICP1'
    #$scope.dfName = 'IMF,PGI,1.0'

    $scope.key = ''
    #$scope.key = '....'

    $scope.customParams = ''
    #$scope.customParams = 'format=samistat'

    $scope.responseVersion = null

#-------------------------------------------------------------------------------
# Code for making requests to the WS

    $scope.getDimensions = () ->
        $scope.state.dimensionError = false
        $scope.state.dimensionRequestRunning = true
        $http.get( $scope.dimUrl, { withCredentials: true } ).success(onDimensions).error(onError)


    $scope.getData = () ->
        $scope.startRequest = new Date()
        $scope.state.dataError = false
        $scope.state.dataRequestRunning = true
        $http.get( $scope.dataUrl, { withCredentials: true } ).success(onData).error(onErrorData)

#-------------------------------------------------------------------------------
# Code for handling responses to requests

    onDimensions = (data, status, headers, config) ->
        $scope.state.dimensionRequestRunning = false
        $scope.state.dimensionError = false

        $scope.response =
            status: status
            headers: headers
            errors: []

        $scope.responseVersion = data['sdmx-proto-json']

        dimensions = $scope.dimensions = data.dimensions

        dimensions.seriesKeyDims = []
        switch data['sdmx-proto-json']
            when '2012-09-13'
                for dimId in dimensions.id
                    dim = dimensions[dimId]

                    if dim.type is 'time'
                        dimensions.timeDimension = dim
                    else
                        dimensions.seriesKeyDims.push dimId

                    codes = []
                    for codeId, i in dim.codes.id
                        code = dim.codes[codeId]
                        code.checked = false
                        code.order = i
                        if dim.type is 'time'
                            code.start = new Date code.start
                            code.end = new Date code.end
                        codes.push code
                    dim.codes = codes

                    dim.codes[0].checked = true
                    dim.show = false
            when '2012-11-15'
                for dimId in dimensions.id
                    dim = dimensions[dimId]

                    if dim.type is 'time'
                        dimensions.timeDimension = dim
                    else
                        dimensions.seriesKeyDims.push dimId

                    for code in dim.codes
                        code.checked = false
                        if dim.type is 'time'
                            code.start = new Date code.start
                            code.end = new Date code.end

                    dim.codes[0].checked = true
                    dim.show = false
            else
                $scope.state.dimensionError = true
                $scope.response.errors.push "Unsupported response version #{data['sdmx-proto-json']}"

        $scope.changeCheckedCodes()


    onData = (data, status, headers, config) ->
        $scope.requestRuntime = new Date() - $scope.startRequest
        start = new Date()
        $scope.state.dataError = false
        $scope.state.dataRequestRunning = false

        $scope.response =
            status: status
            headers: headers

        $scope.data = data
        data.commonDimensions = []

        switch data['sdmx-proto-json']
            when '2012-09-13'
                onData1 data
            when '2012-11-15'
                onData2 data
            else
                $scope.state.dataError = true
                $scope.response.errors.push "Unsupported response version #{data['sdmx-proto-json']}"

        $scope.displayRuntime = new Date() - start


    getAttributeValue = (attribute, value) ->
        value ?= attribute.default
        value = attribute.codes[value].name if attribute.codes?
        value


    onData2 = (data) ->
        seriesKeyDims = data.dimensions.seriesKeyDims = []
        for dimId in data.dimensions.id
            dim = data.dimensions[dimId]

            if dim.type is 'time'
                data.dimensions.timeDimension = dim
                for code in dim.codes
                    # convert date strings to Javascript dates
                    code.start = new Date code.start
                    code.end = new Date code.end

                continue

            # store series key dimensions (dimensions other than time)
            seriesKeyDims.push dimId

            # if a dimension has only one value store in separately for display
            if dim.codes.length is 1
                data.commonDimensions.push {
                    name: dim.name
                    value: dim.codes[0].name
                }

        # build an array of time series (data is in $scope)
        data.timeseries = []
        for obj in data.data
            continue unless obj.observations? and obj.dimensions?

            series =
                key: obj.dimensions
                show: false
                keycodes: []
                keynames: []
                attributes: []
                observations: []

            dimensions = $scope.data.dimensions
            for dimId, i in dimensions.seriesKeyDims
                dim = dimensions[dimId]
                code = dim.codes[obj.dimensions[i]]
                series.keycodes.push code.id
                continue if dim.codes.length is 1 # dim is a common dimension
                series.keynames.push {
                    name: dim.name
                    value: code.name
                }

            timePeriods = dimensions.timeDimension.codes
            for obs in obj.observations
                continue unless obs[1]?

                obsAttrs = []
                for attrId, val of obs.attributes
                    obsAttrs.push {
                        name: data.attributes[attrId].name
                        value: val
                    }

                series.observations.push {
                    date: timePeriods[obs[0]].end
                    value: obs[1]
                    attributes: obsAttrs
                }

            for attrId, val of obj.attributes
                series.attributes.push {
                    name: data.attributes[attrId].name
                    value: getAttributeValue data.attributes[attrId], val
                }

            for obj2 in data.data
                continue if obj2.observations?
                continue unless obj2.attributes? and obj2.dimensions?
                continue if obj2.dimensions.length is 0

                match = true
                for code, i in obj.dimensions
                    continue unless obj2.dimensions[i]?
                    continue if code is obj2.dimensions[i]
                    match = false
                    break

                if match
                    for attrId, val of obj2.attributes
                        series.attributes.push {
                            name: data.attributes[attrId].name
                            value: getAttributeValue data.attributes[attrId], val
                        }

            data.timeseries.push series


    onData1 = (data) ->
        seriesKeyDims = data.dimensions.seriesKeyDims = []
        for dimId in data.dimensions.id
            dim = data.dimensions[dimId]

            if dim.type is 'time'
                data.dimensions.timeDimension = dim
                for codeId in dim.codes.id
                    code = dim.codes[codeId]
                    # convert date strings to Javascript dates
                    code.start = new Date code.start
                    code.end = new Date code.end

                continue

            # store series key dimensions (dimensions other than time)
            seriesKeyDims.push dimId

            # if a dimension has only one value store in separately for display
            if dim.codes.id.length is 1
                data.commonDimensions.push {
                    name: dim.name
                    value: dim.codes[dim.codes.id[0]].name
                }

        # calculate and store multipliers for measure index calculations
        data.dimensions.multipliers = []
        prev = 1
        for dim in data.dimensions.id.slice().reverse()
            data.dimensions.multipliers.push prev
            prev *= data.dimensions[dim].codes.id.length
        data.dimensions.multipliers.reverse()

        # calculate and store multipliers for attribute value index calculations
        for attrId in data.attributes.id
            attr = data.attributes[attrId]
            attr.multipliers = []
            prev = 1
            for dim in attr.dimension.slice().reverse()
                attr.multipliers.push prev
                prev *= data.dimensions[dim].codes.id.length
            attr.multipliers.reverse()

        # calculate multipliers for series key dimensions
        seriesCount = 1
        multipliers = []
        codeLengths = []
        for dim in seriesKeyDims
            multipliers.push seriesCount
            codeLengths.push data.dimensions[dim].codes.id.length
            seriesCount *= data.dimensions[dim].codes.id.length

        # build an array of time series (data is in $scope)
        data.timeseries = []
        for i in [0..seriesCount-1]
            key = []
            for length, j in codeLengths
                codeIndex = Math.floor( i / multipliers[j] ) % length
                key.push codeIndex
            data.timeseries.push createTimeSeries key


    createTimeSeries = (key) ->
        series =
            key: key
            show: false
            keycodes: []
            keynames: []
            attributes: []
            observations: []

        dimensions = $scope.data.dimensions
        for dimId, i in dimensions.seriesKeyDims
            dim = dimensions[dimId]
            code = dim.codes.id[series.key[i]]
            series.keycodes.push code
            continue if dim.codes.id.length is 1 # dim is a common dimension
            series.keynames.push {
                name: dim.name
                value: dim.codes[code].name
            }

        series.attributes = getTimeSeriesAttributes series.key
        series.observations = getTimeSeriesObservations series.key

        series


    getTimeSeriesObservations = (key) ->
        obs = []
        obsIndex = 0
        dimensions = $scope.data.dimensions
        for dimId, i in dimensions.seriesKeyDims
            dimIndex = dimensions[dimId].index
            obsIndex += key[i] * dimensions.multipliers[dimIndex]

        timePeriods = dimensions.timeDimension.codes
        timeMultiplier = dimensions.multipliers[dimensions.timeDimension.index]
        for period, i in timePeriods.id
            index = obsIndex + (i * timeMultiplier)
            obsVal = $scope.data.measure[index]
            continue unless obsVal?
            obs.push {
                date: timePeriods[period].end
                value: obsVal
                attributes: getObservationAttributes(index)
            }
        obs


    getObservationAttributes = (index) ->
        attrs = []
        attributes = $scope.data.attributes
        dimensions = $scope.data.dimensions

        for attrId in attributes.id
            attr = attributes[attrId]
            continue unless attr.dimension.length is dimensions.length
            attrValue = attr.value[index]
            attrValue ?= attr.default
            continue unless attrValue?
            attrValue = attr.codes[attrValue].name if attr.codes?
            attrs.push {name: attr.name, value: attrValue}

        return undefined if attrs.length is 0
        attrs


    getTimeSeriesAttributes = (key) ->
        attrs = []
        attributes = $scope.data.attributes
        dimensions = $scope.data.dimensions

        for attrId in attributes.id
            attr = attributes[attrId]
            continue if attr.dimension.length is dimensions.id.length
            continue if attr.dimension.length is 0
            index = 0
            for dim, j in attr.dimension
                index += key[dimensions[dim].index] * attr.multipliers[j]
            attrValue = attr.value[index]
            attrValue ?= attr.default
            attrValue = attr.codes[attrValue].name if attr.codes?
            attrs.push {name: attr.name, value: attrValue}

        attrs

#-------------------------------------------------------------------------------
# Code for handling request errors

    onError = (data, status, headers, config) ->
        $scope.state.dimensionRequestRunning = false
        $scope.state.dimensionError = true
        $scope.response =
            status: status
            headers: headers
            errors: data.errors


    onErrorData = (data, status, headers, config) ->
        $scope.state.dataRequestRunning = false
        $scope.state.dataError = true
        $scope.response =
            status: status
            headers: headers
            errors: data.errors


#-------------------------------------------------------------------------------
# Code for the UI

    $scope.showButtonText = (show) ->
        if show
            return 'Hide'
        else
            return 'Show'


    $scope.changeDimUrl = () ->
        $scope.dimUrl = "#{$scope.wsName}/data/#{$scope.dfName}"

        if $scope.key.length
            $scope.dimUrl += "/#{$scope.key}"

        params = []
        params.push "detail=serieskeysonly"
        params.push $scope.customParams if $scope.customParams.length
        $scope.dimUrl += "?" + params.join '&' if params.length

    $scope.changeDimUrl()


    $scope.changeCheckedCodes = () ->
        dimensions = $scope.dimensions
        for dimId in dimensions.id
            dim = dimensions[dimId]
            dim.codes.checked = []
            for code in dim.codes
                dim.codes.checked.push code.id if code.checked

        $scope.changeDataUrl()


    $scope.changeDataUrl = () ->
        $scope.dataUrl = "#{$scope.wsName}/data/#{$scope.dfName}"

        key = []
        dimensions = $scope.dimensions
        for dimId, i in dimensions.id
            dim = dimensions[dimId]
            continue if dim.type is 'time'
            key.push dim.codes.checked

        for codes, i in key
            key[i] = codes.join '+'

        $scope.dataUrl += '/' + key.join '.'

        #periods = calculateStartAndEndPeriods dimensions[$scope.dimensions.timeDimension]

        params = []
        #params.push periods if periods.length
        switch $scope.responseVersion
            when '2012-11-15'
                params.push "dimensionAtObservation=TIME_PERIOD"
            else
                params.push "dimensionAtObservation=AllDimensions"
        params.push $scope.customParams if $scope.customParams.length
        $scope.dataUrl += '?' + params.join '&' if params.length


    calculateStartAndEndPeriods = (timeDimension) ->
        startPeriod = null
        endPeriod = null
        params = ''

        for codeId in timeDimension.codes.id
            code = timeDimension.codes[codeId]
            continue unless code.checked

            if startPeriod?
                if code.start < startPeriod.start
                    startPeriod = code
            else
                startPeriod = code

            if endPeriod?
                if endPeriod.end < code.end
                    endPeriod = code
            else
                endPeriod = code

        if startPeriod?
            params = 'startPeriod=' + startPeriod.id

        if endPeriod?
            params += '&endPeriod=' + endPeriod.id

        params


    return
