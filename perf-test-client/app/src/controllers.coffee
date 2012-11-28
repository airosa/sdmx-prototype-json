demoModule.controller 'MainCtrl', ($scope, $http) ->
    $scope.version = '0.1.6'

    $scope.state =
        httpError: false
        httpErrorData: false
        dataRequestRunning: false
        dimensionRequestRunning: false

    #$scope.wsName = 'http://live-test-ws.nodejitsu.com'
    #$scope.wsName = 'http://localhost:8081'
    #$scope.wsName = 'http://46.137.144.117/FusionCube/ws'
    $scope.wsName = 'http://46.51.142.127:8080/FusionMatrix3/ws'

    #$scope.dfName = 'ECB_ICP1'
    #$scope.dfName = 'IMF,PGI,1.0'
    #$scope.dfName = 'BIS,BISWEB_EERDATAFLOW,1.0'
    $scope.dfName = 'SDMX,T1,1.0'

    #$scope.key = ''
    #$scope.key = '....'
    #$scope.key = '....A'
    #$scope.key = '...GB'
    #$scope.key = 'ALL'
    $scope.key = 'D.0.0.0.0.1'

    $scope.customParams = ''
    #$scope.customParams = 'format=samistat'
    #$scope.customParams = 'lastNObservations=12&outputdates=true'
    $scope.customParams = 'outputdates=true'

#-------------------------------------------------------------------------------
# Setup test formats

    $scope.dimensions = []

    $scope.results = []
    $scope.formats = ['jsonseries','jsonseries2','jsonseries3','jsonseries4','jsonindex','jsonarray']


#-------------------------------------------------------------------------------
# Code for making requests to the WS

    $scope.getDimensions = () ->

        onError = (data, status, headers, config) ->
            $scope.state.testRunning = false
            $scope.state.httpError = true

            $scope.response =
                status: status
                errors: data.errors


        onResults = (data, status, headers, config) ->
            $scope.state.testRunning = false
            $scope.state.httpError = false

            $scope.dimensions = []

            for dimId in data.dimensions.id
                dim = data.dimensions[dimId]
                codes = []
                for key, value of dim.codes
                    codes.push key
                $scope.dimensions.push { id: dimId, codes: codes.join(', ') }

        config =
            method: 'GET'
            url: "#{$scope.wsName}/data/#{$scope.dfName}/ALL?format=jsonseries&detail=seriesKeysOnly"
            cache: false

        $scope.state.httpError = false
        $scope.state.testRunning = true
        $http(config).success(onResults).error(onError)


    $scope.runTest = (format) ->
        start = (new Date).getTime()
        if window?.performance?.memory?
            startMem = window.performance.memory.usedJSHeapSize

        result =
            format: format
        $scope.results.push result

        transformResponse = (data) -> data

        onResults = (data, status, headers, config) ->
            $scope.state.testRunning = false
            $scope.state.httpError = false

            $scope.response =
                status: status

            result.requestTime = ((new Date).getTime() - start) + ' ms'
            result.size = bytesToSize unescape(encodeURIComponent(data.length)), 2

            start = (new Date).getTime()
            json = JSON.parse data
            result.parseTime = ((new Date).getTime() - start) + ' ms'

            if window?.performance?.memory?
                result.memory = window.performance.memory.usedJSHeapSize - startMem

            start = (new Date).getTime()
            cube = switch result.format
                when 'jsonarray' then new JSONArrayCube json
                when 'jsonindex' then new JSONIndexCube json
                when 'jsonseries' then new JSONSeriesCube json
                when 'jsonseries2' then new JSONSeries2Cube json
                when 'jsonseries3' then new JSONSeries3Cube json
                when 'jsonseries4' then new JSONSeries4Cube json
            result.initTime = ((new Date).getTime() - start) + ' ms'

            stringKey = switch result.format
                when 'jsonarray', 'jsonindex', 'jsonseries4' then false
                else true

            start = (new Date).getTime()
            testCube cube, result, true, stringKey
            calibration = 0 #((new Date).getTime() - start)

            start = (new Date).getTime()
            result.dataChecksum = cube.checkSum()
            result.cubeChecksum = testCube cube, result, false, stringKey
            result.cubeAccessTime = ((new Date).getTime() - start - calibration) + ' ms'

            start = (new Date).getTime()
            testTimeSeries cube, result, true, stringKey
            calibration = 0 # ((new Date).getTime() - start)

            start = (new Date).getTime()
            result.tsChecksum = testTimeSeries cube, result, false, stringKey
            result.tsAccessTime = ((new Date).getTime() - start - calibration) + ' ms'


        onError = (data, status, headers, config) ->
            $scope.state.testRunning = false
            $scope.state.httpError = true

            $scope.response =
                status: status
                errors: data.errors

        config =
            method: 'GET'
            url: getTestUrl format
            transformResponse: transformResponse
            cache: false

        $scope.state.httpError = false
        $scope.state.testRunning = true
        $http(config).success(onResults).error(onError)

#-------------------------------------------------------------------------------
# Objects for the different formats

    class JSONArrayCube
        constructor: (@msg) ->
            @multipliers = []
            prev = 1
            for dimId in @dimensions().reverse()
                @multipliers.push prev
                prev *= @codes(dimId).length
            @multipliers.reverse()

            dims = @dimensions()
            @timeDimensionCodes = @codes( dims[ dims.length - 1 ] )

        dimensions: () ->
            dims = @msg.dimensions.id.slice()
            dims.push 'TIME_PERIOD'
            dims

        codes: (dimension) ->
            @msg.dimensions[dimension].codes.id.slice()

        observation: (key) ->
            index = 0
            for codeIndex, j in key
                index += codeIndex * @multipliers[j]
            @msg.measure[0][index]


        timeSeries: (key) ->
            series =
                observations: []
            last = key.length

            for timePeriod, i in @timeDimensionCodes
                key[last] = i
                obs = @observation(key)
                continue unless obs?
                series.observations.push { value: obs }

            series

        checkSum: ()->
            sum = 0
            for obs in @msg.measure[0]
                sum += +obs
            sum


    class JSONIndexCube
        constructor: (@msg) ->
            @multipliers = []
            prev = 1
            for dimId in @dimensions().reverse()
                @multipliers.push prev
                prev *= @codes(dimId).length
            @multipliers.reverse()

            dims = @dimensions()
            @timeDimensionCodes = @codes( dims[ dims.length - 1 ] )

        dimensions: () ->
            @msg.dimensions.id.slice()

        codes: (dimension) ->
            @msg.dimensions[dimension].codes.slice()

        observation: (key) ->
            index = 0
            for codeIndex, j in key
                index += codeIndex * @multipliers[j]
            @msg.measure[index]?[0]

        timeSeries: (key) ->
            series =
                observations: []
            last = key.length

            for timePeriod, i in @timeDimensionCodes
                key[last] = i
                obs = @observation key
                continue unless obs?
                series.observations.push { value: obs }

            series

        checkSum: () ->
            sum = 0
            for key, val of @msg.measure
                sum += +val[0]
            sum


    class JSONSeriesCube
        constructor: (@msg) ->
            @dimCodes = []
            for dimId in @dimensions()
                @dimCodes.push @codes(dimId)

        dimensions: () ->
            @msg.dimensions.id.slice()

        codes: (dimension) ->
            Object.keys @msg.dimensions[dimension].codes

        observation: (key) ->
            timePeriod = key[key.length-1]
            keyString = key.slice(0,-1).join(':')

            obs = @msg.measure[keyString]?.observations[timePeriod]?[0]
            if obs? then obs else undefined

        timeSeries: (key) ->
            keyString = key.join ':'

            newSeries =
                observations: []

            series = @msg.measure[keyString]

            return newSeries unless series?

            for timePeriod in Object.keys series.observations
                obs = series.observations[timePeriod]
                continue unless obs?
                newSeries.observations.push { value: obs[0] }

            newSeries

        checkSum: () ->
            sum = 0
            for key, val of @msg.measure
                continue unless val.observations?
                for key2, val2 of val.observations
                    sum += +val2[0]
            sum


    class JSONSeries2Cube
        constructor: (@msg) ->
            @dimCodes = []
            for dimId in @dimensions()
                @dimCodes.push @codes(dimId)

        dimensions: () ->
            Object.keys @msg.dimensions

        codes: (dimension) ->
            Object.keys @msg.dimensions[dimension].codes

        observation: (key) ->
            timePeriod = key[key.length-1]
            keyString = key.slice(0,-1).join(':')

            obsIndex = @msg.measure[keyString]?.observations?.TIME_PERIOD.indexOf timePeriod
            return undefined unless obsIndex? and -1 < obsIndex

            obs = @msg.measure[keyString].observations.values[obsIndex]
            if obs? then obs else undefined

        timeSeries: (key) ->
            keyString = key.join ':'

            newSeries =
                observations: []

            series = @msg.measure[keyString]

            return newSeries unless series?

            for obs in series.observations.values
                continue unless obs?
                newSeries.observations.push { value: obs }

            newSeries

        checkSum: () ->
            sum = 0
            for obj, val of @msg.measure
                continue unless val.observations?
                for obs in val.observations.values
                    sum += +obs
            sum


    class JSONSeries3Cube
        constructor: (@msg) ->
            @dimCodes = []
            for dimId in @dimensions()
                @dimCodes.push @codes(dimId)

        dimensions: () ->
            Object.keys @msg.dimensions

        codes: (dimension) ->
            Object.keys @msg.dimensions[dimension].codes

        observation: (key) ->
            timePeriod = key[key.length-1]
            keyString = key.slice(0,-1).join(':')

            obs = @msg.measure[keyString]?.observations[timePeriod]
            if obs? then obs.value else undefined

        timeSeries: (key) ->
            keyString = key.join ':'

            newSeries =
                observations: []

            series = @msg.measure[keyString]

            return newSeries unless series?

            for timePeriod in Object.keys(series.observations).sort()
                obs = series.observations[timePeriod]
                continue unless obs?
                newSeries.observations.push { value: obs.value }

            newSeries

        checkSum: () ->
            sum = 0
            for key, val of @msg.measure
                continue unless val.observations?
                for key2, val2 of val.observations
                    sum += +val2.value
            sum


    class JSONSeries4Cube
        constructor: (@msg) ->
            @dimCodes = {}
            for dimId in @dimensions()
                codes = []
                for code in @msg.dimensions[dimId].codes
                    codes.push code
                @dimCodes[dimId] = codes

            @multipliers = []
            prev = 1
            for dimId in @dimensions().reverse()
                @multipliers.push prev
                prev *= @codes(dimId).length
            @multipliers.reverse()

            @obsIndex = []
            @seriesIndex = []

            for obj in @msg.data
                continue unless obj.dimensions?
                seriesPos = 0
                for codePos, i in obj.dimensions[0...-1]
                    seriesPos += codePos * @multipliers[i]
                @seriesIndex[seriesPos] = obj

                continue unless obj.observations

                lastMultiplier = @multipliers[-1..][0]
                for obs in obj.observations
                    idx = seriesPos + (obs[0] * lastMultiplier)
                    @obsIndex[idx] = obs

        dimensions: () ->
            @msg.dimensions.id.slice()

        codes: (dimension) ->
            @dimCodes[dimension]

        observation: (key) ->
            pos = 0
            for codePos, i in key
                pos += codePos * @multipliers[i]

            @obsIndex[pos]?[1]

        timeSeries: (key) ->
            pos = 0
            for codePos, i in key
                pos += @multipliers[i] * codePos

            newSeries =
                observations: []

            series = @seriesIndex[pos]

            return newSeries unless series?

            for obs in series.observations
                newSeries.observations.push { value: obs[1] }

            newSeries

        checkSum: () ->
            sum = 0
            for obj in @msg.data
                continue unless obj.observations?
                for obs in obj.observations
                    sum += obs[1]
            sum

#-------------------------------------------------------------------------------
# Tests for cube access

    testCube = (cube, result, calibrate, stringKey) ->
        dimensions = cube.dimensions()
        codes = []

        obsCount = 1
        multipliers = []
        codeLengths = []
        prev = 1
        for dimId in dimensions.slice().reverse()
            multipliers.push prev
            dimCodes = cube.codes(dimId)
            codes.push dimCodes
            obsCount *= dimCodes.length
            codeLengths.push dimCodes.length
            prev *= dimCodes.length
        multipliers.reverse()
        codeLengths.reverse()
        codes.reverse()
        result.obsCount = obsCount

        checkSum = 0
        missing = 0
        for i in [0..obsCount-1]
            key = []
            for length, j in codeLengths
                codeIndex = Math.floor( i / multipliers[j] ) % length
                key.push codeIndex

            if stringKey
                for codePos, j in key
                    key[j] = codes[j][codePos]

            obs = cube.observation(key) unless calibrate

            if not obs?
                missing += 1
                continue

            checkSum += obs


        result.density = (1 - (missing / obsCount)).toFixed 2

        checkSum


#-------------------------------------------------------------------------------
# Tests for time series access

    testTimeSeries= (cube, result, calibrate, stringKey) ->
        if window?.performance?.memory?
            startMem = window.performance.memory

        timeSeries = []
        dimensions = cube.dimensions()
        dimensions.pop()

        seriesCount = 1
        multipliers = []
        codeLengths = []
        codes = []
        prev = 1
        for dimId in dimensions.reverse()
            multipliers.push prev
            dimCodes = cube.codes(dimId)
            codes.push dimCodes
            seriesCount *= dimCodes.length
            codeLengths.push dimCodes.length
            prev *= dimCodes.length
        multipliers.reverse()
        codeLengths.reverse()
        codes.reverse()
        result.tsCount = seriesCount

        checkSum = 0
        for i in [0..seriesCount-1]
            key = []
            for length, j in codeLengths
                codeIndex = Math.floor( i / multipliers[j] ) % length
                key.push codeIndex

            if stringKey
                for codePos, j in key
                    key[j] = codes[j][codePos]

            series = cube.timeSeries key unless calibrate

            continue unless series?
            timeSeries.push series

        for series in timeSeries
            for obs in series.observations
                continue unless obs.value?
                checkSum += obs.value

        if window?.performance?.memory?
            result.tsMemory = window.performance.memory - startMem

        checkSum


#-------------------------------------------------------------------------------
# Helpers

    bytesToSize = (bytes, precision) ->
        kilobyte = 1024
        megabyte = kilobyte * 1024
        gigabyte = megabyte * 1024
        terabyte = gigabyte * 1024

        if bytes >= 0 and bytes < kilobyte
            return bytes + ' B'

        else if bytes >= kilobyte and bytes < megabyte
            return (bytes / kilobyte).toFixed(precision) + ' KB'

        else if bytes >= megabyte and bytes < gigabyte
            return (bytes / megabyte).toFixed(precision) + ' MB'

        else if bytes >= gigabyte and bytes < terabyte
            return (bytes / gigabyte).toFixed(precision) + ' GB'

        else if bytes >= terabyte
            return (bytes / terabyte).toFixed(precision) + ' TB'

        else
            return bytes + ' B'


#-------------------------------------------------------------------------------
# Code for the UI


    getTestUrl = (format) ->
        testUrl = "#{$scope.wsName}/data/#{$scope.dfName}"

        if $scope.key.length
            testUrl += "/#{$scope.key}"

        params = []
        params.push $scope.customParams if $scope.customParams.length
        params.push 'format=' + format
        testUrl += "?" + params.join '&' if params.length
        $scope.url = testUrl
        testUrl

    return
